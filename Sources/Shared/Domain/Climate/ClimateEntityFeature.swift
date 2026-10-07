import Foundation

/// The climate domain's `supported_features` bitmask, mirroring Home Assistant core's
/// `ClimateEntityFeature`.
public struct ClimateEntityFeature: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let targetTemperature = ClimateEntityFeature(rawValue: 1 << 0)
    public static let targetTemperatureRange = ClimateEntityFeature(rawValue: 1 << 1)
    public static let targetHumidity = ClimateEntityFeature(rawValue: 1 << 2)
    public static let fanMode = ClimateEntityFeature(rawValue: 1 << 3)
    public static let presetMode = ClimateEntityFeature(rawValue: 1 << 4)
    public static let swingMode = ClimateEntityFeature(rawValue: 1 << 5)
    public static let auxHeat = ClimateEntityFeature(rawValue: 1 << 6)
    public static let turnOff = ClimateEntityFeature(rawValue: 1 << 7)
    public static let turnOn = ClimateEntityFeature(rawValue: 1 << 8)
    public static let swingHorizontalMode = ClimateEntityFeature(rawValue: 1 << 9)

    /// Parses the `supported_features` value from an attributes dictionary.
    public init(attributes: [String: Any]) {
        self.init(rawValue: (attributes["supported_features"] as? NSNumber)?.intValue ?? 0)
    }
}
