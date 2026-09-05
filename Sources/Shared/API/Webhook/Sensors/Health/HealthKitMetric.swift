#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Describes one Apple Health sample type and how it becomes a Home Assistant sensor.
///
/// The catalog in `HealthKitMetric+…` files is plain data: `identifier` holds the raw
/// `HKQuantityTypeIdentifier` (or, for sleep, `HKCategoryTypeIdentifier`) string so metrics
/// introduced by newer versions of iOS can be listed unconditionally — `HealthKitService` simply
/// skips the ones the running OS doesn't know about.
public struct HealthKitMetric: Equatable, Hashable, Sendable {
    /// Stable sensor ID sent to Home Assistant. Never change one that has already shipped.
    public let uniqueID: String
    /// Raw value of the `HKQuantityTypeIdentifier` this metric reads, or of the
    /// `HKCategoryTypeIdentifier` for a `.sleep` metric. Several sleep metrics share the one type.
    public let identifier: String
    /// Entity name sent to Home Assistant. Not localized, matching the other webhook sensors.
    public let name: String
    /// Material Design icon name, including the `mdi:` prefix.
    public let icon: String
    /// Explanation shown under the sensor in settings, `nil` for a metric that needs none.
    public let footer: HealthKitMetricFooter?
    /// Unit of measurement reported to Home Assistant, `nil` for unitless metrics.
    public let unit: String?
    /// Unit the samples are read in, which is also what `unit` describes. A `.sleep` metric has no
    /// samples to convert; its `.minute` only names what the summed durations are reported in.
    public let queryUnit: HealthKitMetricUnit
    public let aggregation: HealthKitMetricAggregation
    public let category: HealthKitMetricCategory
    public let deviceClass: DeviceClass?
    public let stateClass: SensorStateClass?
    /// How far back a `.mostRecent` metric looks for a sample, or a `.sleep` metric for a night.
    /// Ignored for `.cumulativeSum`.
    public let lookbackDays: Int
    /// Multiplier applied to the raw HealthKit value, e.g. 100 to turn a 0…1 fraction into a percentage.
    public let scale: Double
    /// Digits kept after the decimal point. `0` reports the state as an integer.
    public let decimalPlaces: Int
    /// Earliest iOS major version providing `identifier`, used by tests to catch typos.
    public let availableFromIOS: Int

    public init(
        uniqueID: String,
        identifier: String,
        name: String,
        icon: String,
        footer: HealthKitMetricFooter? = nil,
        unit: String?,
        queryUnit: HealthKitMetricUnit,
        aggregation: HealthKitMetricAggregation,
        category: HealthKitMetricCategory,
        deviceClass: DeviceClass? = nil,
        stateClass: SensorStateClass? = nil,
        lookbackDays: Int = 7,
        scale: Double = 1,
        decimalPlaces: Int = 2,
        availableFromIOS: Int = 8
    ) {
        self.uniqueID = uniqueID
        self.identifier = identifier
        self.name = name
        self.icon = icon
        self.footer = footer
        self.unit = unit
        self.queryUnit = queryUnit
        self.aggregation = aggregation
        self.category = category
        self.deviceClass = deviceClass
        self.stateClass = stateClass
        self.lookbackDays = lookbackDays
        self.scale = scale
        self.decimalPlaces = decimalPlaces
        self.availableFromIOS = availableFromIOS
    }

    /// Applies `scale` and `decimalPlaces` to a raw HealthKit value.
    public func state(for value: Double) -> Any {
        let scaled = value * scale
        guard decimalPlaces > 0 else {
            return Int(scaled.rounded())
        }
        let factor = pow(10, Double(decimalPlaces))
        return (scaled * factor).rounded() / factor
    }
}
#endif
