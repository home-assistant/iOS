import Foundation
import PromiseKit
import Shared

class SensorListViewModel: ObservableObject {
    /// Every sensor, always sorted alphabetically no matter whether it is enabled or not.
    @Published var sensors: [WebhookSensor] = []
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

    /// How many Apple Health metrics are switched on, shown as the badge of the link to their screen.
    var enabledHealthSensorCount: Int {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return HealthKitMetric.all.filter { Current.sensors.isEnabled(uniqueID: $0.uniqueID) }.count
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

    init() {
        Current.sensors.register(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
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

    /// Switches one sensor on or off, asking iOS for whatever permission it needs as it goes on.
    func setEnabled(_ isEnabled: Bool, for sensor: WebhookSensor) {
        Current.sensors.setEnabled(isEnabled, for: sensor)
        guard let uniqueID = sensor.UniqueID else { return }
        requestPermissionsIfNeeded(isEnabled: isEnabled, uniqueIDs: [uniqueID])
    }

    func updateAllSensors(isEnabled: Bool) {
        let uniqueIDs = sensors.compactMap(\.UniqueID)
        Current.sensors.setEnabled(isEnabled, forUniqueIDs: uniqueIDs)
        requestPermissionsIfNeeded(isEnabled: isEnabled, uniqueIDs: uniqueIDs)
    }

    private func requestPermissionsIfNeeded(isEnabled: Bool, uniqueIDs: [String]) {
        guard isEnabled, !uniqueIDs.isEmpty else { return }
        Current.requestSensorPermissions(uniqueIDs)
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

// MARK: - SensorObserver

extension SensorListViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        refresh()
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        firstly {
            update.sensors
        }.done { [weak self] sensors in
            let sorted = Self.sortedAlphabetically(Self.excludingHealthSensors(sensors))
            DispatchQueue.main.async {
                self?.sensors = sorted
                self?.lastUpdateDate = update.on
            }
        }.catch { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }
}
