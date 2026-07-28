#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Metrics that don't fit the other categories.
    static let otherMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_underwater_depth",
            identifier: "HKQuantityTypeIdentifierUnderwaterDepth",
            name: "Underwater Depth",
            icon: "mdi:diving-scuba",
            unit: "m",
            queryUnit: .meter,
            aggregation: .mostRecent,
            category: .other,
            deviceClass: .distance,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 1,
            availableFromIOS: 16
        ),
        HealthKitMetric(
            uniqueID: "health_water_temperature",
            identifier: "HKQuantityTypeIdentifierWaterTemperature",
            name: "Water Temperature",
            icon: "mdi:coolant-temperature",
            unit: "°C",
            queryUnit: .degreeCelsius,
            aggregation: .mostRecent,
            category: .other,
            deviceClass: .temperature,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 1,
            availableFromIOS: 16
        ),
    ]
}
#endif
