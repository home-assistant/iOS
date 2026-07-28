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
        HealthKitMetric(
            uniqueID: "health_blood_alcohol_content",
            identifier: "HKQuantityTypeIdentifierBloodAlcoholContent",
            name: "Blood Alcohol Content",
            icon: "mdi:glass-cocktail",
            unit: "%",
            queryUnit: .percent,
            aggregation: .mostRecent,
            category: .vitals,
            stateClass: .measurement,
            lookbackDays: 1,
            scale: 100,
            decimalPlaces: 3
        ),
        HealthKitMetric(
            uniqueID: "health_insulin_delivery",
            identifier: "HKQuantityTypeIdentifierInsulinDelivery",
            name: "Insulin Delivery",
            icon: "mdi:needle",
            unit: "IU",
            queryUnit: .internationalUnit,
            aggregation: .cumulativeSum,
            category: .vitals,
            stateClass: .totalIncreasing,
            decimalPlaces: 1,
            availableFromIOS: 11
        ),
        HealthKitMetric(
            uniqueID: "health_electrodermal_activity",
            identifier: "HKQuantityTypeIdentifierElectrodermalActivity",
            name: "Electrodermal Activity",
            icon: "mdi:flash",
            unit: "µS",
            queryUnit: .microsiemens,
            aggregation: .mostRecent,
            category: .vitals,
            stateClass: .measurement
        ),
        HealthKitMetric(
            uniqueID: "health_uv_exposure",
            identifier: "HKQuantityTypeIdentifierUVExposure",
            name: "UV Index",
            icon: "mdi:weather-sunny",
            unit: nil,
            queryUnit: .count,
            aggregation: .mostRecent,
            category: .vitals,
            stateClass: .measurement,
            lookbackDays: 1,
            decimalPlaces: 0
        ),
        HealthKitMetric(
            uniqueID: "health_number_of_alcoholic_beverages",
            identifier: "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages",
            name: "Alcoholic Beverages",
            icon: "mdi:glass-mug-variant",
            unit: "drinks",
            queryUnit: .count,
            aggregation: .cumulativeSum,
            category: .vitals,
            stateClass: .totalIncreasing,
            decimalPlaces: 0,
            availableFromIOS: 15
        ),
    ]
}
#endif
