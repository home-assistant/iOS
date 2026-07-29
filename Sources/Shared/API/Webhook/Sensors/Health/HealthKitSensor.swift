#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import PromiseKit

public final class HealthKitSensor: SensorProvider {
    /// HealthKit is happy to run these in parallel, but a few at a time keeps a sensor update from
    /// scheduling well over a hundred queries at once.
    private static let maximumConcurrentQueries = 8

    private static let reportedMetricsKey = "healthSensorsReported"

    public let request: SensorProviderRequest

    public init(request: SensorProviderRequest) {
        self.request = request
    }

    public static func isHealthSensor(uniqueID: String?) -> Bool {
        guard let uniqueID else { return false }
        return HealthKitMetric.metric(uniqueID: uniqueID) != nil
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let metrics = Self.reportedMetrics()
        guard !metrics.isEmpty else {
            return .value([])
        }

        guard Current.healthKitService.isAvailable() else {
            return .value(metrics.map { Self.sensor(metric: $0, value: nil) })
        }

        let now = Current.date()
        let (promise, seal) = Promise<[WebhookSensor]>.pending()

        Task {
            let values = await Self.values(for: metrics, now: now)
            let states = values.reduce(into: [String: Double]()) { result, value in
                if let number = value.value {
                    result[value.metric.uniqueID] = number
                }
            }
            seal.fulfill(metrics.map { Self.sensor(metric: $0, value: states[$0.uniqueID]) })
        }

        return promise
    }

    /// The metrics worth putting on the wire: everything currently enabled, plus anything that was
    /// enabled at some point, so a sensor the user turns off goes unavailable in Home Assistant instead
    /// of silently keeping its last value.
    private static func reportedMetrics() -> [HealthKitMetric] {
        let prefs = Current.settingsStore.prefs
        var reported = Set(prefs.object(forKey: reportedMetricsKey) as? [String] ?? [])

        let enabled = HealthKitMetric.all
            .filter { Current.sensors.isEnabled(uniqueID: $0.uniqueID) }
            .map(\.uniqueID)

        if !Set(enabled).isSubset(of: reported) {
            reported.formUnion(enabled)
            prefs.set(Array(reported), forKey: reportedMetricsKey)
        }

        return HealthKitMetric.all.filter { reported.contains($0.uniqueID) }
    }

    private static func values(for metrics: [HealthKitMetric], now: Date) async -> [HealthSensorValue] {
        await withTaskGroup(of: HealthSensorValue.self) { group in
            var pending = metrics.makeIterator()
            var started = 0

            while started < maximumConcurrentQueries, let metric = pending.next() {
                group.addTask { await self.value(for: metric, now: now) }
                started += 1
            }

            var values = [HealthSensorValue]()
            while let value = await group.next() {
                values.append(value)
                if let metric = pending.next() {
                    group.addTask { await self.value(for: metric, now: now) }
                }
            }
            return values
        }
    }

    private static func value(for metric: HealthKitMetric, now: Date) async -> HealthSensorValue {
        guard Current.sensors.isEnabled(uniqueID: metric.uniqueID) else {
            return HealthSensorValue(metric: metric, value: nil)
        }

        let calendar = Current.calendar()
        let start: Date
        switch metric.aggregation {
        case .cumulativeSum:
            start = calendar.startOfDay(for: now)
        case .mostRecent:
            start = calendar.date(byAdding: .day, value: -metric.lookbackDays, to: now)
                ?? calendar.startOfDay(for: now)
        }

        let value = try? await Current.healthKitService.queryValue(metric, start, now)
        return HealthSensorValue(metric: metric, value: value)
    }

    private static func sensor(metric: HealthKitMetric, value: Double?) -> WebhookSensor {
        let state: Any = value.map { metric.state(for: $0) } ?? "unavailable"
        let sensor = WebhookSensor(
            name: metric.name,
            uniqueID: metric.uniqueID,
            icon: metric.icon,
            state: state,
            unit: metric.unit,
            stateClass: metric.stateClass
        )
        sensor.DeviceClass = metric.deviceClass
        return sensor
    }
}
#endif
