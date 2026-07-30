#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public struct HealthSensorValue: Equatable, Sendable {
    public let metric: HealthKitMetric
    /// Newest value for the metric, `nil` when HealthKit had no matching sample — or wasn't readable.
    public let value: Double?
    /// `true` when HealthKit refused the read (a locked device, or access revoked) instead of answering
    /// that it has no samples. Those metrics are left out of the update rather than reported as
    /// `unavailable`, so the entity keeps the value it already had.
    public let isUnreadable: Bool

    public init(metric: HealthKitMetric, value: Double?, isUnreadable: Bool = false) {
        self.metric = metric
        self.value = value
        self.isUnreadable = isUnreadable
    }
}
#endif
