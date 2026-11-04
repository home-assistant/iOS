#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public struct HealthSensorValue: Equatable, Sendable {
    public let metric: HealthKitMetric
    /// `nil` when HealthKit has no sample for the metric, or when the read failed — `isUnreadable` tells
    /// the two apart.
    public let value: Double?
    /// `true` when HealthKit refused the read — a locked device, or access revoked.
    public let isUnreadable: Bool

    public init(metric: HealthKitMetric, value: Double?, isUnreadable: Bool = false) {
        self.metric = metric
        self.value = value
        self.isUnreadable = isUnreadable
    }
}
#endif
