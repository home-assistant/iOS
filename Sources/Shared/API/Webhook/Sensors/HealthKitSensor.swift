#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import PromiseKit

public final class HealthKitSensor: SensorProvider {
    public enum Metric: CaseIterable, Codable {
        case steps
        case restingHeartRate

        public var uniqueID: String {
            switch self {
            case .steps: return "health_steps"
            case .restingHeartRate: return "health_resting_heart_rate"
            }
        }

        public var name: String {
            switch self {
            case .steps: return "Health Steps"
            case .restingHeartRate: return "Resting Heart Rate"
            }
        }

        public var icon: String {
            switch self {
            case .steps: return "mdi:walk"
            case .restingHeartRate: return "mdi:heart-pulse"
            }
        }

        public var unit: String {
            switch self {
            case .steps: return "steps"
            case .restingHeartRate: return "bpm"
            }
        }
    }

    public let request: SensorProviderRequest

    public init(request: SensorProviderRequest) {
        self.request = request
    }

    public static func isHealthSensor(uniqueID: String?) -> Bool {
        guard let uniqueID else { return false }
        return Metric.allCases.contains { $0.uniqueID == uniqueID }
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        guard Current.healthKitService.isAvailable() else {
            return .value(Self.unavailableSensors())
        }

        let start = Current.calendar().startOfDay(for: Current.date())
        let end = Current.date()
        let restingHeartRateStart = Current.calendar().date(byAdding: .day, value: -7, to: end) ?? start
        let (promise, seal) = Promise<[WebhookSensor]>.pending()

        Task {
            async let steps = value(
                for: .steps,
                start: start,
                end: end,
                restingHeartRateStart: restingHeartRateStart
            )
            async let restingHeartRate = value(
                for: .restingHeartRate,
                start: start,
                end: end,
                restingHeartRateStart: restingHeartRateStart
            )

            let values = await [steps, restingHeartRate].compactMap { $0 }
            seal.fulfill(Self.sensors(from: values))
        }

        return promise
    }

    private func value(
        for metric: Metric,
        start: Date,
        end: Date,
        restingHeartRateStart: Date
    ) async -> HealthSensorValue? {
        guard Current.sensors.isEnabled(uniqueID: metric.uniqueID) else {
            return nil
        }

        switch metric {
        case .steps:
            let value = try? await Current.healthKitService.queryStepCount(start, end)
            return HealthSensorValue(metric: metric, value: value.map(Double.init))
        case .restingHeartRate:
            let value = try? await Current.healthKitService.queryLatestRestingHeartRate(restingHeartRateStart, end)
            return HealthSensorValue(metric: metric, value: value)
        }
    }

    private static func sensors(from values: [HealthSensorValue]) -> [WebhookSensor] {
        Metric.allCases.map { metric in
            let value = values.first(where: { $0.metric == metric })?.value
            return sensor(metric: metric, value: value)
        }
    }

    private static func unavailableSensors() -> [WebhookSensor] {
        Metric.allCases.map { sensor(metric: $0, value: nil) }
    }

    private static func sensor(metric: Metric, value: Double?) -> WebhookSensor {
        let state: Any
        switch metric {
        case .steps:
            state = value.map { Int($0) } ?? "unavailable"
        case .restingHeartRate:
            state = value ?? "unavailable"
        }

        return WebhookSensor(
            name: metric.name,
            uniqueID: metric.uniqueID,
            icon: metric.icon,
            state: state,
            unit: metric.unit
        )
    }
}
#endif
