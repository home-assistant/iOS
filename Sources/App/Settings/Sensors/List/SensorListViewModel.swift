import Foundation
import PromiseKit
import Shared

class SensorListViewModel: ObservableObject {
    /// The server whose selection this screen edits, or `nil` on the root screen of an install with
    /// more than one server, where the sensors themselves live one navigation step further in.
    let server: Server?

    /// Every sensor, always sorted alphabetically no matter whether it is enabled or not.
    @Published var sensors: [WebhookSensor] = []
    /// Mirrored here so toggling a sensor re-renders the list; `SensorContainer` isn't observable.
    @Published private(set) var enabledUniqueIDs: Set<String> = []
    /// Kept current from `serversDidChange`, so adding or removing one while this screen is open
    /// doesn't leave it offering a server that is gone or hiding one that has just arrived.
    @Published private(set) var servers: [Server] = []
    @Published var lastUpdateDate: Date?
    @Published var periodicUpdateInterval: TimeInterval? = Current.settingsStore.periodicUpdateInterval
    @Published var searchTerm: String = ""
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether the Apple Health sensor screen can be reached from here.
    var isHealthKitAvailable: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return Current.healthKitService.isAvailable()
        #else
        return false
        #endif
    }

    /// How many Apple Health metrics are switched on for this server, shown as the badge of the
    /// link to their screen.
    var enabledHealthSensorCount: Int {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return HealthKitMetric.all.filter { enabledUniqueIDs.contains($0.uniqueID) }.count
        #else
        return 0
        #endif
    }

    /// The Apple Health link stays visible while searching when the query matches its screen, so
    /// health sensors remain reachable even though they live on their own screen.
    var showHealthSection: Bool {
        guard isHealthKitAvailable else { return false }
        guard isSearching else { return true }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if L10n.SettingsSensors.Health.Sensors.title.localizedStandardContains(term) { return true }
        return HealthKitMetric.all.contains { $0.name.localizedStandardContains(term) }
        #else
        return false
        #endif
    }

    /// The sensors matching the current search term, or all of them when not searching.
    var filteredSensors: [WebhookSensor] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return sensors }
        return sensors.filter { $0.Name?.localizedStandardContains(term) ?? false }
    }

    /// The servers the root screen lists, each leading to its own copy of this screen. Empty while
    /// there is only one, whose sensors are shown on the root screen itself.
    var selectableServers: [Server] {
        servers.count > 1 ? servers.sorted() : []
    }

    /// The servers matching the current search term. Searching the root screen is searching the
    /// list it actually shows, which is the servers rather than one of their sensors.
    var filteredServers: [Server] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return selectableServers }
        return selectableServers.filter { $0.info.name.localizedStandardContains(term) }
    }

    var allSensorsEnabled: Bool {
        !sensors.isEmpty && sensors.allSatisfy { isEnabled($0) }
    }

    /// The root screen. It edits the only server directly when there is one, and lists the servers
    /// instead when there are several, each of which gets its own copy of this screen.
    convenience init() {
        let all = Current.servers.all
        self.init(server: all.count == 1 ? all.first : nil)
    }

    init(server: Server?) {
        self.server = server
        self.enabledUniqueIDs = Self.currentlyEnabledUniqueIDs(for: server)
        self.servers = Current.servers.all
        Current.sensors.register(observer: self)
        Current.servers.add(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
        Current.servers.remove(observer: self)
    }

    func isEnabled(_ sensor: WebhookSensor) -> Bool {
        guard let uniqueID = sensor.UniqueID else { return false }
        return enabledUniqueIDs.contains(uniqueID)
    }

    func refresh() {
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }

    func setPeriodicUpdateInterval(_ interval: TimeInterval?) {
        periodicUpdateInterval = interval
        Current.settingsStore.periodicUpdateInterval = interval
    }

    /// Switches one sensor on or off for this screen's server, asking iOS for whatever permission
    /// it needs as it goes on.
    func setEnabled(_ isEnabled: Bool, for sensor: WebhookSensor) {
        guard let server, let uniqueID = sensor.UniqueID else { return }
        Current.sensors.setEnabled(isEnabled, forUniqueID: uniqueID, on: server)
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs(for: server)
        requestPermissionsIfNeeded(isEnabled: isEnabled, uniqueIDs: [uniqueID])
    }

    func updateAllSensors(isEnabled: Bool) {
        guard let server else { return }
        let uniqueIDs = sensors.compactMap(\.UniqueID)
        Current.sensors.setEnabled(isEnabled, forUniqueIDs: uniqueIDs, on: server)
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs(for: server)
        requestPermissionsIfNeeded(isEnabled: isEnabled, uniqueIDs: uniqueIDs)
    }

    private func requestPermissionsIfNeeded(isEnabled: Bool, uniqueIDs: [String]) {
        guard isEnabled, !uniqueIDs.isEmpty else { return }
        Current.requestSensorPermissions(uniqueIDs)
    }

    private static func currentlyEnabledUniqueIDs(for server: Server?) -> Set<String> {
        guard let server else { return [] }
        return Current.sensors.enabledUniqueIDs(for: server)
    }

    /// Apple Health metrics are managed on their own screen — there are over a hundred of them, so
    /// leaving them here would bury every other sensor.
    static func excludingHealthSensors(_ sensors: [WebhookSensor]) -> [WebhookSensor] {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return sensors.filter { !HealthKitSensor.isHealthSensor(uniqueID: $0.UniqueID) }
        #else
        return sensors
        #endif
    }

    static func sortedAlphabetically(_ sensors: [WebhookSensor]) -> [WebhookSensor] {
        sensors.sorted { lhs, rhs in
            let comparison = (lhs.Name ?? "").localizedStandardCompare(rhs.Name ?? "")
            if comparison == .orderedSame {
                return (lhs.UniqueID ?? "") < (rhs.UniqueID ?? "")
            }
            return comparison == .orderedAscending
        }
    }
}

// MARK: - ServerObserver

extension SensorListViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        DispatchQueue.main.async { [weak self] in
            self?.servers = serverManager.all
        }
    }
}

// MARK: - SensorObserver

extension SensorListViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        // The root screen of an install with several servers lists the servers themselves, so a
        // change to what one of them receives has nothing to bring up to date here.
        guard server != nil else { return }
        refresh()
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        firstly {
            update.sensors
        }.done { [weak self] sensors in
            guard let self else { return }
            let sorted = Self.sortedAlphabetically(Self.excludingHealthSensors(sensors))
            let enabled = Self.currentlyEnabledUniqueIDs(for: server)
            DispatchQueue.main.async {
                self.sensors = sorted
                self.enabledUniqueIDs = enabled
                self.lastUpdateDate = update.on
            }
        }.catch { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }
}
