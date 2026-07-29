#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Movement, workouts and energy metrics.
    static let activityMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_distance_walking_running",
            identifier: "HKQuantityTypeIdentifierDistanceWalkingRunning",
            name: "Walking + Running Distance",
            icon: "mdi:walk",
            unit: "km",
            queryUnit: .kilometer,
            aggregation: .cumulativeSum,
            category: .activity,
            deviceClass: .distance,
            stateClass: .totalIncreasing
        ),
        HealthKitMetric(
            uniqueID: "health_active_energy_burned",
            identifier: "HKQuantityTypeIdentifierActiveEnergyBurned",
            name: "Active Energy",
            icon: "mdi:fire",
            unit: "kcal",
            queryUnit: .kilocalorie,
            aggregation: .cumulativeSum,
            category: .activity,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_basal_energy_burned",
            identifier: "HKQuantityTypeIdentifierBasalEnergyBurned",
            name: "Resting Energy",
            icon: "mdi:fire",
            unit: "kcal",
            queryUnit: .kilocalorie,
            aggregation: .cumulativeSum,
            category: .activity,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_flights_climbed",
            identifier: "HKQuantityTypeIdentifierFlightsClimbed",
            name: "Flights Climbed",
            icon: "mdi:stairs-up",
            unit: "floors",
            queryUnit: .count,
            aggregation: .cumulativeSum,
            category: .activity,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_apple_exercise_time",
            identifier: "HKQuantityTypeIdentifierAppleExerciseTime",
            name: "Exercise Time",
            icon: "mdi:timer-outline",
            unit: "min",
            queryUnit: .minute,
            aggregation: .cumulativeSum,
            category: .activity,
            deviceClass: .duration,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_vo2_max",
            identifier: "HKQuantityTypeIdentifierVO2Max",
            name: "VO2 Max",
            icon: "mdi:lungs",
            unit: "mL/kg·min",
            queryUnit: .milliliterPerKilogramPerMinute,
            aggregation: .mostRecent,
            category: .activity,
            stateClass: .measurement,
            lookbackDays: 365,
            decimalPlaces: 1,
            availableFromIOS: 11
        ),
    ]
}
#endif
