#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

public extension HealthKitMetric {
    /// Sleep metrics, all read from the one sleep analysis category type. Each reports the most recent
    /// night, so its value holds through the day; see `HealthKitSleepSummary`.
    static let sleepMetrics: [HealthKitMetric] = [
        sleepMetric(
            uniqueID: "health_sleep_duration",
            name: "Sleep Duration",
            icon: "mdi:sleep",
            stages: HealthKitSleepStage.asleepStages
        ),
        sleepMetric(uniqueID: "health_sleep_awake", name: "Awake", icon: "mdi:eye", stages: [.awake]),
        sleepMetric(uniqueID: "health_sleep_core", name: "Core Sleep", icon: "mdi:bed", stages: [.core]),
        sleepMetric(uniqueID: "health_sleep_deep", name: "Deep Sleep", icon: "mdi:sleep", stages: [.deep]),
        sleepMetric(uniqueID: "health_sleep_rem", name: "REM Sleep", icon: "mdi:brain", stages: [.rem]),
    ]

    private static func sleepMetric(
        uniqueID: String,
        name: String,
        icon: String,
        stages: Set<HealthKitSleepStage>
    ) -> HealthKitMetric {
        HealthKitMetric(
            uniqueID: uniqueID,
            identifier: HealthKitSleepStage.sleepAnalysisIdentifier,
            name: name,
            icon: icon,
            unit: "min",
            queryUnit: .minute,
            aggregation: .sleep(stages: stages),
            category: .sleep,
            deviceClass: .duration,
            // Not `totalIncreasing`: the value drops when a shorter night replaces a longer one, and a
            // drop of under 10% isn't a reset to Home Assistant, which would subtract it from the total.
            stateClass: .measurement,
            decimalPlaces: 0
        )
    }
}
#endif
