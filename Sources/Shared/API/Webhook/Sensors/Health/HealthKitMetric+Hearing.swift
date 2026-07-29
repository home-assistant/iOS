#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Audio exposure metrics.
    static let hearingMetrics: [HealthKitMetric] = [
        HealthKitMetric(
            uniqueID: "health_environmental_audio_exposure",
            identifier: "HKQuantityTypeIdentifierEnvironmentalAudioExposure",
            name: "Environmental Audio Exposure",
            icon: "mdi:volume-high",
            unit: "dB",
            queryUnit: .decibelSoundPressureLevel,
            aggregation: .mostRecent,
            category: .hearing,
            deviceClass: .soundPressure,
            stateClass: .measurement,
            decimalPlaces: 0,
            availableFromIOS: 13
        ),
        HealthKitMetric(
            uniqueID: "health_headphone_audio_exposure",
            identifier: "HKQuantityTypeIdentifierHeadphoneAudioExposure",
            name: "Headphone Audio Exposure",
            icon: "mdi:headphones",
            unit: "dB",
            queryUnit: .decibelSoundPressureLevel,
            aggregation: .mostRecent,
            category: .hearing,
            deviceClass: .soundPressure,
            stateClass: .measurement,
            decimalPlaces: 0,
            availableFromIOS: 13
        ),
        HealthKitMetric(
            uniqueID: "health_environmental_sound_reduction",
            identifier: "HKQuantityTypeIdentifierEnvironmentalSoundReduction",
            name: "Environmental Sound Reduction",
            icon: "mdi:ear-hearing-off",
            unit: "dB",
            queryUnit: .decibelSoundPressureLevel,
            aggregation: .mostRecent,
            category: .hearing,
            deviceClass: .soundPressure,
            stateClass: .measurement,
            decimalPlaces: 0,
            availableFromIOS: 16
        ),
    ]
}
#endif
