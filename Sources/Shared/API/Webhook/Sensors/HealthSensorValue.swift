#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public struct HealthSensorValue: Codable, Equatable {
    public let metric: HealthKitSensor.Metric
    public let value: Double?

    public init(metric: HealthKitSensor.Metric, value: Double?) {
        self.metric = metric
        self.value = value
    }
}
#endif
