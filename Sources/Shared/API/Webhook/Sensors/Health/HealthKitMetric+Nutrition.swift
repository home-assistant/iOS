#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Food and drink intake metrics.
    static let nutritionMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_dietary_water",
            identifier: "HKQuantityTypeIdentifierDietaryWater",
            name: "Water",
            icon: "mdi:cup-water",
            unit: "mL",
            queryUnit: .milliliter,
            aggregation: .cumulativeSum,
            category: .nutrition,
            deviceClass: .volume,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
    ]
}
#endif
