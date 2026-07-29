#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Gait and mobility metrics.
    static let mobilityMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_walking_speed",
            identifier: "HKQuantityTypeIdentifierWalkingSpeed",
            name: "Walking Speed",
            icon: "mdi:walk",
            unit: "m/s",
            queryUnit: .meterPerSecond,
            aggregation: .mostRecent,
            category: .mobility,
            deviceClass: .speed,
            stateClass: .measurement,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_walking_step_length",
            identifier: "HKQuantityTypeIdentifierWalkingStepLength",
            name: "Walking Step Length",
            icon: "mdi:walk",
            unit: "cm",
            queryUnit: .centimeter,
            aggregation: .mostRecent,
            category: .mobility,
            deviceClass: .distance,
            stateClass: .measurement,
            decimalPlaces: 1,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_walking_asymmetry_percentage",
            identifier: "HKQuantityTypeIdentifierWalkingAsymmetryPercentage",
            name: "Walking Asymmetry",
            icon: "mdi:walk",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .mobility,
            stateClass: .measurement,
            scale: 100,
            decimalPlaces: 1,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_walking_double_support_percentage",
            identifier: "HKQuantityTypeIdentifierWalkingDoubleSupportPercentage",
            name: "Walking Double Support",
            icon: "mdi:walk",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .mobility,
            stateClass: .measurement,
            scale: 100,
            decimalPlaces: 1,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_apple_walking_steadiness",
            identifier: "HKQuantityTypeIdentifierAppleWalkingSteadiness",
            name: "Walking Steadiness",
            icon: "mdi:walk",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .mobility,
            stateClass: .measurement,
            lookbackDays: 30,
            scale: 100,
            decimalPlaces: 1,
            availableFromIOS: 15
        ),
        HealthKitMetric(
            uniqueID: "health_six_minute_walk_test_distance",
            identifier: "HKQuantityTypeIdentifierSixMinuteWalkTestDistance",
            name: "Six-Minute Walk Distance",
            icon: "mdi:walk",
            unit: "m",
            queryUnit: .meter,
            aggregation: .mostRecent,
            category: .mobility,
            deviceClass: .distance,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 0,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_stair_ascent_speed",
            identifier: "HKQuantityTypeIdentifierStairAscentSpeed",
            name: "Stair Ascent Speed",
            icon: "mdi:stairs-up",
            unit: "m/s",
            queryUnit: .meterPerSecond,
            aggregation: .mostRecent,
            category: .mobility,
            deviceClass: .speed,
            stateClass: .measurement,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_stair_descent_speed",
            identifier: "HKQuantityTypeIdentifierStairDescentSpeed",
            name: "Stair Descent Speed",
            icon: "mdi:stairs-down",
            unit: "m/s",
            queryUnit: .meterPerSecond,
            aggregation: .mostRecent,
            category: .mobility,
            deviceClass: .speed,
            stateClass: .measurement,
            availableFromIOS: 14
        ),
        HealthKitMetric(
            uniqueID: "health_number_of_times_fallen",
            identifier: "HKQuantityTypeIdentifierNumberOfTimesFallen",
            name: "Number of Times Fallen",
            icon: "mdi:human-cane",
            unit: "falls",
            queryUnit: .count,
            aggregation: .cumulativeSum,
            category: .mobility,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
    ]
}
#endif
