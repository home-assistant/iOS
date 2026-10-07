#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Vital signs and other clinical metrics.
    static let vitalsMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_body_temperature",
            identifier: "HKQuantityTypeIdentifierBodyTemperature",
            name: "Body Temperature",
            icon: "mdi:thermometer",
            unit: "°C",
            queryUnit: .degreeCelsius,
            aggregation: .mostRecent,
            category: .vitals,
            deviceClass: .temperature,
            stateClass: .measurement,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_basal_body_temperature",
            identifier: "HKQuantityTypeIdentifierBasalBodyTemperature",
            name: "Basal Body Temperature",
            icon: "mdi:thermometer",
            unit: "°C",
            queryUnit: .degreeCelsius,
            aggregation: .mostRecent,
            category: .vitals,
            deviceClass: .temperature,
            stateClass: .measurement,
            decimalPlaces: 1
        ),
        HealthKitMetric(
            uniqueID: "health_blood_glucose",
            identifier: "HKQuantityTypeIdentifierBloodGlucose",
            name: "Blood Glucose",
            icon: "mdi:diabetes",
            unit: "mg/dL",
            queryUnit: .milligramPerDeciliter,
            aggregation: .mostRecent,
            category: .vitals,
            deviceClass: .bloodGlucoseConcentration,
            stateClass: .measurement,
            lookbackDays: 1,
            decimalPlaces: 0
        ),
    ]
}
#endif
