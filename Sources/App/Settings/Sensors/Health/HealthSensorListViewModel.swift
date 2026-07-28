#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import Shared

@MainActor
class HealthSensorListViewModel: ObservableObject {
    @Published var searchTerm = ""
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published private(set) var isHealthKitAvailable = false
    /// Mirrored here so toggling a sensor re-renders the list; `SensorContainer` isn't observable.
    @Published private(set) var enabledUniqueIDs: Set<String> = []

    init() {
        // New metrics ship disabled, so make sure that has happened before the toggles are drawn.
        HealthKitSensor.seedInitialEnabledState()
        isHealthKitAvailable = Current.healthKitService.isAvailable()
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    var visibleCategories: [HealthKitMetricCategory] {
        HealthKitMetricCategory.allCases.filter { !metrics(in: $0).isEmpty }
    }

    var areAllEnabled: Bool {
        enabledUniqueIDs.count == HealthKitMetric.all.count
    }

    func metrics(in category: HealthKitMetricCategory) -> [HealthKitMetric] {
        let metrics = HealthKitMetric.metrics(in: category)
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return metrics }
        return metrics.filter { $0.name.localizedCaseInsensitiveContains(term) }
    }

    func isEnabled(_ metric: HealthKitMetric) -> Bool {
        enabledUniqueIDs.contains(metric.uniqueID)
    }

    func setEnabled(_ isEnabled: Bool, for metric: HealthKitMetric) {
        Current.sensors.setEnabled(isEnabled, forUniqueID: metric.uniqueID)
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    func setAllEnabled(_ isEnabled: Bool) {
        Current.sensors.setEnabled(isEnabled, forUniqueIDs: HealthKitMetric.all.map(\.uniqueID))
        enabledUniqueIDs = Self.currentlyEnabledUniqueIDs()
    }

    func requestAuthorization() async {
        do {
            try await Current.healthKitService.requestReadAuthorization()
            isHealthKitAvailable = Current.healthKitService.isAvailable()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private static func currentlyEnabledUniqueIDs() -> Set<String> {
        Set(HealthKitMetric.all.map(\.uniqueID).filter { Current.sensors.isEnabled(uniqueID: $0) })
    }
}
#endif
