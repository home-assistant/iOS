#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// How the samples HealthKit returns for a metric are reduced to a single sensor state.
public enum HealthKitMetricAggregation: Equatable, Hashable, Sendable {
    /// Adds every sample recorded since the start of the current day, e.g. the steps taken today.
    /// Only valid for quantity types whose aggregation style is cumulative.
    case cumulativeSum
    /// Uses the newest sample within the metric's lookback window, e.g. the latest weight reading.
    case mostRecent
    /// Adds up the time spent in any of `stages` during the most recent night, i.e. the latest sleep
    /// day with samples. Only valid for the sleep analysis category type; see `HealthKitSleepSummary`.
    case sleep(stages: Set<HealthKitSleepStage>)
    /// Reads one field of the current day's activity summary: a Fitness ring's progress or its goal.
    /// Only valid for the activity summary type; see `HealthKitActivitySummaryField`.
    case activitySummary(HealthKitActivitySummaryField)

    /// The field read from the activity summary, `nil` for the sample-based aggregations.
    public var activitySummaryField: HealthKitActivitySummaryField? {
        if case let .activitySummary(field) = self {
            return field
        }
        return nil
    }
}
#endif
