#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// The unit a metric's samples are read in. Kept free of `HealthKit` types so the metric catalog
/// stays plain data; `HealthKitMetricUnit+HKUnit` does the translation when a query runs.
public enum HealthKitMetricUnit: String, CaseIterable, Sendable {
    case count
    case countPerMinute
    case percent
    case centimeter
    case meter
    case kilometer
    case meterPerSecond
    case gram
    case kilogram
    case milligram
    case microgram
    case liter
    case milliliter
    case literPerMinute
    case milliliterPerKilogramPerMinute
    case kilocalorie
    case kilocaloriePerKilogramPerHour
    case millisecond
    case minute
    case watt
    case degreeCelsius
    case millimeterOfMercury
    case milligramPerDeciliter
    case decibelSoundPressureLevel
    case microsiemens
    case internationalUnit
    case effortScore
}
#endif
