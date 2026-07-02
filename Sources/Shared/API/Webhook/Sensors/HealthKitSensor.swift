import Foundation
import PromiseKit

public final class HealthKitSensor: SensorProvider {
    enum HealthKitSensorError: LocalizedError {
        case authorizationFailed
        case unavailable

        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return L10n.SettingsSensors.Health.Error.authorizationFailed
            case .unavailable:
                return L10n.SettingsSensors.Health.Error.unavailable
            }
        }
    }

    public enum AuthorizationStatus: Equatable {
        case unavailable
        case available
    }

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
        guard Current.healthKit.isAvailable() else {
            return .value(Self.unavailableSensors())
        }

        let start = Current.calendar().startOfDay(for: Current.date())
        let end = Current.date()
        let restingHeartRateStart = Current.calendar().date(byAdding: .day, value: -7, to: end) ?? start

        return firstly { () -> Guarantee<[Result<HealthSensorValue?>]> in
            when(resolved: Metric.allCases.map { metric in
                value(for: metric, start: start, end: end, restingHeartRateStart: restingHeartRateStart)
            })
        }.map { results -> [HealthSensorValue] in
            let values = results.compactMap { result -> HealthSensorValue? in
                if case let .fulfilled(value) = result {
                    return value
                } else {
                    return nil
                }
            }

            return values
        }.map(Self.sensors(from:))
    }

    private func value(
        for metric: Metric,
        start: Date,
        end: Date,
        restingHeartRateStart: Date
    ) -> Promise<HealthSensorValue?> {
        guard Current.sensors.isEnabled(uniqueID: metric.uniqueID) else {
            return .value(nil)
        }

        switch metric {
        case .steps:
            return Current.healthKit.queryStepCount(start, end).map {
                HealthSensorValue(metric: metric, value: $0.map(Double.init))
            }
        case .restingHeartRate:
            return Current.healthKit.queryLatestRestingHeartRate(restingHeartRateStart, end).map {
                HealthSensorValue(metric: metric, value: $0)
            }
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

public struct HealthSensorValue: Codable, Equatable {
    public let metric: HealthKitSensor.Metric
    public let value: Double?

    public init(metric: HealthKitSensor.Metric, value: Double?) {
        self.metric = metric
        self.value = value
    }
}
