#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Shipped before the full Apple Health catalog existed; its ID must stay stable.
    static let steps = HealthKitMetric(
        uniqueID: "health_steps",
        identifier: "HKQuantityTypeIdentifierStepCount",
        name: "Health Steps",
        icon: "mdi:walk",
        unit: "steps",
        queryUnit: .count,
        aggregation: .cumulativeSum,
        category: .activity,
        stateClass: .totalIncreasing,
        decimalPlaces: 0
    )

    /// Movement, workouts and energy metrics.
    static let activityMetrics: [HealthKitMetric] = [
        steps,
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
    ] + activityRingMetrics

    /// What the Fitness app's rings add to the samples above: the daily goals, and stand hours, which
    /// have no quantity type to sum. All are read from the day's activity summary. Move and Exercise
    /// progress are "Active Energy" and "Exercise Time" above, and the goal IDs extend theirs; the
    /// goals keep the names Fitness gives them, so "Move Goal" is the goal of "Active Energy".
    static let activityRingMetrics: [HealthKitMetric] = [
        ringMetric(
            .goal(.move),
            uniqueID: "health_active_energy_burned_goal",
            name: "Move Goal",
            footer: .moveGoalEnergyOnly
        ),
        ringMetric(
            .goal(.exercise),
            uniqueID: "health_apple_exercise_time_goal",
            name: "Exercise Goal",
            footer: .ringNeedsWatch
        ),
        ringMetric(
            .progress(.stand),
            uniqueID: "health_apple_stand_hours",
            name: "Stand Hours",
            icon: "mdi:human-handsup",
            footer: .ringNeedsWatch
        ),
        ringMetric(
            .goal(.stand),
            uniqueID: "health_apple_stand_hours_goal",
            name: "Stand Goal",
            footer: .ringNeedsWatch
        ),
    ]

    private static func ringMetric(
        _ field: HealthKitActivitySummaryField,
        uniqueID: String,
        name: String,
        icon: String = "mdi:bullseye-arrow",
        footer: HealthKitMetricFooter? = nil
    ) -> HealthKitMetric {
        let unit: String
        let queryUnit: HealthKitMetricUnit
        let deviceClass: DeviceClass?
        switch field.ring {
        case .move: (unit, queryUnit, deviceClass) = ("kcal", .kilocalorie, nil)
        case .exercise: (unit, queryUnit, deviceClass) = ("min", .minute, .duration)
        // A count of the hours stood in, not a length of time, so no duration device class: 7 of 12
        // shouldn't be offered in minutes.
        case .stand: (unit, queryUnit, deviceClass) = ("hours", .count, nil)
        }

        return HealthKitMetric(
            uniqueID: uniqueID,
            identifier: HealthKitActivitySummaryField.identifier,
            name: name,
            icon: icon,
            footer: footer,
            unit: unit,
            queryUnit: queryUnit,
            aggregation: .activitySummary(field),
            category: .activity,
            deviceClass: deviceClass,
            // Progress resets with the day like the other daily totals; a goal is a setting, and one
            // that can be lowered.
            stateClass: field.isGoal ? .measurement : .totalIncreasing,
            decimalPlaces: 0
        )
    }
}
#endif
