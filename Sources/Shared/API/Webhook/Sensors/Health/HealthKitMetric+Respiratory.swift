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
        HealthKitMetric(
            uniqueID: "health_forced_expiratory_volume1",
            identifier: "HKQuantityTypeIdentifierForcedExpiratoryVolume1",
            name: "Forced Expiratory Volume (FEV1)",
            icon: "mdi:lungs",
            unit: "L",
            queryUnit: .liter,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            lookbackDays: 30
        ),
        HealthKitMetric(
            uniqueID: "health_forced_vital_capacity",
            identifier: "HKQuantityTypeIdentifierForcedVitalCapacity",
            name: "Forced Vital Capacity",
            icon: "mdi:lungs",
            unit: "L",
            queryUnit: .liter,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            lookbackDays: 30
        ),
        HealthKitMetric(
            uniqueID: "health_peak_expiratory_flow_rate",
            identifier: "HKQuantityTypeIdentifierPeakExpiratoryFlowRate",
            name: "Peak Expiratory Flow Rate",
            icon: "mdi:lungs",
            unit: "L/min",
            queryUnit: .literPerMinute,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_inhaler_usage",
            identifier: "HKQuantityTypeIdentifierInhalerUsage",
            name: "Inhaler Usage",
            icon: "mdi:spray",
            unit: "times",
            queryUnit: .count,
            aggregation: .cumulativeSum,
            category: .respiratory,
            stateClass: .totalIncreasing,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_sleeping_breathing_disturbances",
            identifier: "HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances",
            name: "Breathing Disturbances",
            icon: "mdi:lungs",
            unit: nil,
            queryUnit: .count,
            aggregation: .mostRecent,
            category: .respiratory,
            stateClass: .measurement,
            decimalPlaces: 1,
            availableFromIOS: 18
        ),
    ]
}
#endif
