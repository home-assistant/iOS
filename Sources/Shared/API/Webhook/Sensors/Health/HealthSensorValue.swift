#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public struct HealthSensorValue: Equatable, Sendable {
    public let metric: HealthKitMetric
    public let value: Double?

    public init(metric: HealthKitMetric, value: Double?) {
        self.metric = metric
        self.value = value
    }
}
#endif
