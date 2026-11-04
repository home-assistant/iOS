#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Body measurement metrics.
    static let bodyMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_body_mass",
            identifier: "HKQuantityTypeIdentifierBodyMass",
            name: "Weight",
            icon: "mdi:scale-bathroom",
            unit: "kg",
            queryUnit: .kilogram,
            aggregation: .mostRecent,
            category: .body,
            deviceClass: .weight,
            stateClass: .measurement,
            lookbackDays: 365,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_body_fat_percentage",
            identifier: "HKQuantityTypeIdentifierBodyFatPercentage",
            name: "Body Fat Percentage",
            icon: "mdi:scale-bathroom",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .body,
            stateClass: .measurement,
            lookbackDays: 365,
            scale: 100,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_lean_body_mass",
            identifier: "HKQuantityTypeIdentifierLeanBodyMass",
            name: "Lean Body Mass",
            icon: "mdi:weight-lifter",
            unit: "kg",
            queryUnit: .kilogram,
            aggregation: .mostRecent,
            category: .body,
            deviceClass: .weight,
            stateClass: .measurement,
            lookbackDays: 365,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_height",
            identifier: "HKQuantityTypeIdentifierHeight",
            name: "Height",
            icon: "mdi:human-male-height",
            unit: "cm",
            queryUnit: .centimeter,
            aggregation: .mostRecent,
            category: .body,
            deviceClass: .distance,
            stateClass: .measurement,
            lookbackDays: 3650,
            decimalPlaces: 1
        ),
    ]
}
#endif
