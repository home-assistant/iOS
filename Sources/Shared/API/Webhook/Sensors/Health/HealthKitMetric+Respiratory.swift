#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Breathing and lung function metrics.
    static let respiratoryMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_respiratory_rate",
            identifier: "HKQuantityTypeIdentifierRespiratoryRate",
            name: "Respiratory Rate",
            icon: "mdi:lungs",
            unit: "br/min",
            queryUnit: .countPerMinute,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_oxygen_saturation",
            identifier: "HKQuantityTypeIdentifierOxygenSaturation",
            name: "Blood Oxygen",
            icon: "mdi:water-percent",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            scale: 100,
            decimalPlaces: 1
        ),
    ]
}
#endif
