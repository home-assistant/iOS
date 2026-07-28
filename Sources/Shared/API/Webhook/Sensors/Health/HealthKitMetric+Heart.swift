#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Shipped before the full Apple Health catalog existed; its ID must stay stable.
    static let restingHeartRate = HealthKitMetric(
        uniqueID: "health_resting_heart_rate",
        identifier: "HKQuantityTypeIdentifierRestingHeartRate",
        name: "Resting Heart Rate",
        icon: "mdi:heart-pulse",
        unit: "bpm",
        queryUnit: .countPerMinute,
        aggregation: .mostRecent,
        category: .heart,
        stateClass: .measurement,
        availableFromIOS: 11
    )

    /// Heart and circulation metrics.
    static let heartMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_heart_rate",
            identifier: "HKQuantityTypeIdentifierHeartRate",
            name: "Heart Rate",
            icon: "mdi:heart-pulse",
            unit: "bpm",
            queryUnit: .countPerMinute,
            aggregation: .mostRecent,
            category: .heart,
            stateClass: .measurement,
            lookbackDays: 1,
            decimalPlaces: 0
        ),
        restingHeartRate,
        HealthKitMetric(
            uniqueID: "health_walking_heart_rate_average",
            identifier: "HKQuantityTypeIdentifierWalkingHeartRateAverage",
            name: "Walking Heart Rate Average",
            icon: "mdi:heart-pulse",
            unit: "bpm",
            queryUnit: .countPerMinute,
            aggregation: .mostRecent,
            category: .heart,
            stateClass: .measurement,
            decimalPlaces: 0,
            availableFromIOS: 11
        ),
        HealthKitMetric(
            uniqueID: "health_heart_rate_variability",
            identifier: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
            name: "Heart Rate Variability",
            icon: "mdi:heart-pulse",
            unit: "ms",
            queryUnit: .millisecond,
            aggregation: .mostRecent,
            category: .heart,
            deviceClass: .duration,
            stateClass: .measurement,
            decimalPlaces: 1,
            availableFromIOS: 11
        ),
        HealthKitMetric(
            uniqueID: "health_heart_rate_recovery_one_minute",
            identifier: "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute",
            name: "Heart Rate Recovery",
            icon: "mdi:heart-pulse",
            unit: "bpm",
            queryUnit: .countPerMinute,
            aggregation: .mostRecent,
            category: .heart,
            stateClass: .measurement,
            decimalPlaces: 0,
            availableFromIOS: 16
        ),
        HealthKitMetric(
            uniqueID: "health_atrial_fibrillation_burden",
            identifier: "HKQuantityTypeIdentifierAtrialFibrillationBurden",
            name: "Atrial Fibrillation Burden",
            icon: "mdi:heart-flash",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .heart,
            stateClass: .measurement,
            lookbackDays: 30,
            scale: 100,
            decimalPlaces: 1,
            availableFromIOS: 16
        ),
        HealthKitMetric(
            uniqueID: "health_peripheral_perfusion_index",
            identifier: "HKQuantityTypeIdentifierPeripheralPerfusionIndex",
            name: "Peripheral Perfusion Index",
            icon: "mdi:heart-pulse",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .heart,
            stateClass: .measurement,
            scale: 100,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_blood_pressure_systolic",
            identifier: "HKQuantityTypeIdentifierBloodPressureSystolic",
            name: "Blood Pressure Systolic",
            icon: "mdi:heart-pulse",
            unit: "mmHg",
            queryUnit: .millimeterOfMercury,
            aggregation: .mostRecent,
            category: .heart,
            deviceClass: .pressure,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_blood_pressure_diastolic",
            identifier: "HKQuantityTypeIdentifierBloodPressureDiastolic",
            name: "Blood Pressure Diastolic",
            icon: "mdi:heart-pulse",
            unit: "mmHg",
            queryUnit: .millimeterOfMercury,
            aggregation: .mostRecent,
            category: .heart,
            deviceClass: .pressure,
            stateClass: .measurement,
            lookbackDays: 30,
            decimalPlaces: 0
        ),
    ]
}
#endif
