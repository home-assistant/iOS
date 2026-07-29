#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Every Apple Health metric the app knows how to report, grouped by category.
    ///
    /// This is deliberately a subset of HealthKit: the metrics the Android companion already reports
    /// through Health Connect, plus the ones named in the iOS feature requests. Metrics whose
    /// `identifier` or unit the running version of iOS doesn't provide are skipped when a query runs,
    /// so the list can still name types newer than the deployment target.
    static let all: [HealthKitMetric] = [
        activityMetrics,
        bodyMetrics,
        heartMetrics,
        nutritionMetrics,
        respiratoryMetrics,
        vitalsMetrics,
    ].flatMap { $0 }

    /// The metrics of one category, in the order they should be displayed.
    static func metrics(in category: HealthKitMetricCategory) -> [HealthKitMetric] {
        all.filter { $0.category == category }
    }

    static func metric(uniqueID: String) -> HealthKitMetric? {
        allByUniqueID[uniqueID]
    }

    private static let allByUniqueID: [String: HealthKitMetric] = Dictionary(
        all.map { ($0.uniqueID, $0) },
        uniquingKeysWith: { first, _ in first }
    )
}
#endif
