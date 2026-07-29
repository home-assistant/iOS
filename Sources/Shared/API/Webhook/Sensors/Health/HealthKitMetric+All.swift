#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

// TODO: Grow the catalog in follow-up PRs. Deliberately left out of the first release, roughly in
// the order they've been asked for:
//   - Sleep. The most requested thing missing here, and the one that needs real work: HealthKit
//     models it as a category type, not a quantity type, so it needs its own query and state shape.
//   - Mobility: walking speed, step length, asymmetry, double support, stair speeds, walking
//     steadiness, six-minute walk distance.
//   - Hearing: environmental and headphone audio exposure, environmental sound reduction.
//   - The rest of Nutrition: the macro and micronutrient breakdown, caffeine, dietary energy.
//   - Sport-specific activity: cycling power and cadence, running form, swimming, rowing, skiing,
//     paddle sports, workout effort scores, time in daylight.
//   - Other: underwater depth, water temperature, UV exposure, insulin delivery, blood alcohol.
// Adding one back is a catalog entry plus, if its category is gone, a `HealthKitMetricCategory`
// case and its localized name.

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
