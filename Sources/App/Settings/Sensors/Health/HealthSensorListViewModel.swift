#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import PromiseKit
import Shared

@MainActor
class HealthSensorListViewModel: ObservableObject {
    @Published var searchTerm = ""
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published private(set) var isHealthKitAvailable = false
    /// Mirrored here so toggling a sensor re-renders the list; `SensorContainer` isn't observable.
    @Published private(set) var enabledUniqueIDs: Set<String> = []
    /// Latest reported value per metric. Apple Health sensors are kept out of the main sensor list, so
    /// this screen is where their values are visible.
    @Published private(set) var stateDescriptions: [String: String] = [:]

    init() {
        self.isHealthKitAvailable = Current.healthKitService.isAvailable()
        self.enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
        Current.sensors.register(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
    }

    var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var visibleCategories: [HealthKitMetricCategory] {
        HealthKitMetricCategory.allCases.filter { !metrics(in: $0).isEmpty }
    }

    var areAllEnabled: Bool {
        enabledUniqueIDs.count == HealthKitMetric.all.count
    }

    var totalSensorCount: Int {
        HealthKitMetric.all.count
    }

    func metrics(in category: HealthKitMetricCategory) -> [HealthKitMetric] {
        let metrics = HealthKitMetric.metrics(in: category)
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return metrics }
        return metrics.filter { $0.name.localizedStandardContains(term) }
    }

    func isEnabled(_ metric: HealthKitMetric) -> Bool {
        enabledUniqueIDs.contains(metric.uniqueID)
    }

    func stateDescription(for metric: HealthKitMetric) -> String? {
        stateDescriptions[metric.uniqueID]
    }

    func setEnabled(_ isEnabled: Bool, for metric: HealthKitMetric) {
        Current.sensors.setEnabled(isEnabled, forUniqueID: metric.uniqueID)
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    func setAllEnabled(_ isEnabled: Bool) {
        Current.sensors.setEnabled(isEnabled, forUniqueIDs: HealthKitMetric.all.map(\.uniqueID))
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    func enableAll(in category: HealthKitMetricCategory) {
        Current.sensors.setEnabled(true, forUniqueIDs: metrics(in: category).map(\.uniqueID))
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    /// HealthKit only prompts for types it hasn't been asked about, so asking again after switching
    /// more sensors on is what gets permission for them.
    func requestAuthorization() async {
        do {
            try await Current.healthKitService.requestReadAuthorization()
            isHealthKitAvailable = Current.healthKitService.isAvailable()
            refreshSensors()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func refreshSensors() {
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { [weak self] error in
            Task { @MainActor in
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }

    private static func currentlyEnabledUniqueIDs() -> Set<String> {
        Set(HealthKitMetric.all.map(\.uniqueID).filter { Current.sensors.isEnabled(uniqueID: $0) })
    }

    private nonisolated static func healthStateDescriptions(from sensors: [WebhookSensor]) -> [String: String] {
        sensors.reduce(into: [String: String]()) { result, sensor in
            guard let uniqueID = sensor.UniqueID,
                  HealthKitSensor.isHealthSensor(uniqueID: uniqueID),
                  let description = sensor.StateDescription else { return }
            result[uniqueID] = description
        }
    }
}

// MARK: - SensorObserver

extension HealthSensorListViewModel: SensorObserver {
    nonisolated func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {}

    nonisolated func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { sensors in
            let descriptions = Self.healthStateDescriptions(from: sensors)
            Task { @MainActor [weak self] in
                self?.stateDescriptions = descriptions
            }
        }
    }
}
#endif
