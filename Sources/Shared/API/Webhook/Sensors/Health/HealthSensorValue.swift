#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public struct HealthSensorValue: Equatable, Sendable {
    public let metric: HealthKitMetric
    public let value: Double?
    /// `true` when HealthKit refused the read — a locked device, or access revoked — rather than answering
    /// that it has no samples.
    public let isUnreadable: Bool

    public init(metric: HealthKitMetric, value: Double?, isUnreadable: Bool = false) {
        self.metric = metric
        self.value = value
        self.isUnreadable = isUnreadable
    }
}
#endif
