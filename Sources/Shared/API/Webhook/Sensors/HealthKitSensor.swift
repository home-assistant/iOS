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

    private static let cacheLifetime: TimeInterval = 15 * 60
    public let request: SensorProviderRequest

    public init(request: SensorProviderRequest) {
        self.request = request
    }

    public static func isHealthSensor(uniqueID: String?) -> Bool {
        guard let uniqueID else { return false }
        return Metric.allCases.contains { $0.uniqueID == uniqueID }
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        guard Current.settingsStore.healthSensorsEnabled else {
            if Current.settingsStore.healthSensorsHaveBeenEnabled {
                return .value(Self.unavailableSensors())
            } else {
                return .value([])
            }
        }

        guard Current.healthKit.isAvailable() else {
            return .value(Self.unavailableSensors())
        }

        if shouldUseCache, let cached = Current.settingsStore.healthSensorCache, canUseCache(cached) {
            return .value(Self.sensors(from: cached))
        }

        let start = Current.calendar().startOfDay(for: Current.date())
        let end = Current.date()
        let restingHeartRateStart = Current.calendar().date(byAdding: .day, value: -7, to: end) ?? start

        return firstly { () -> Guarantee<[Result<HealthSensorValue?>]> in
            when(resolved: Metric.allCases.map { metric in
                value(for: metric, start: start, end: end, restingHeartRateStart: restingHeartRateStart)
            })
        }.map { results -> HealthSensorCache in
            let values = results.compactMap { result -> HealthSensorValue? in
                if case let .fulfilled(value) = result {
                    return value
                } else {
                    return nil
                }
            }

            return HealthSensorCache(fetchedAt: Current.date(), values: values)
        }.get { cache in
            Current.settingsStore.healthSensorCache = cache
        }.map(Self.sensors(from:))
    }

    private var shouldUseCache: Bool {
        switch request.reason {
        case .registration:
            break
        case let .trigger(reason):
            if reason == LocationUpdateTrigger.Manual.rawValue {
                return false
            }
        }

        guard let cache = Current.settingsStore.healthSensorCache else {
            return false
        }

        return Current.date().timeIntervalSince(cache.fetchedAt) < Self.cacheLifetime
    }

    private func canUseCache(_ cache: HealthSensorCache) -> Bool {
        Metric.allCases.allSatisfy { metric in
            !Current.sensors.isEnabled(uniqueID: metric.uniqueID) || cache.values.contains { $0.metric == metric }
        }
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

    private static func sensors(from cache: HealthSensorCache) -> [WebhookSensor] {
        Metric.allCases.map { metric in
            let value = cache.values.first(where: { $0.metric == metric })?.value
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

public struct HealthSensorCache: Codable, Equatable {
    public let fetchedAt: Date
    public let values: [HealthSensorValue]

    public init(fetchedAt: Date, values: [HealthSensorValue]) {
        self.fetchedAt = fetchedAt
        self.values = values
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
