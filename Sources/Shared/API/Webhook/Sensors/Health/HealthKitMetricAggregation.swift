#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// How the samples HealthKit returns for a metric are reduced to a single sensor state.
public enum HealthKitMetricAggregation: String, CaseIterable, Sendable {
    /// Adds every sample recorded since the start of the current day, e.g. the steps taken today.
    /// Only valid for quantity types whose aggregation style is cumulative.
    case cumulativeSum
    /// Uses the newest sample within the metric's lookback window, e.g. the latest weight reading.
    case mostRecent
}
#endif
