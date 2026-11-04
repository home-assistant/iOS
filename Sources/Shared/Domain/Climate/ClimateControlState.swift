import Foundation
import HAKit

/// Snapshot of a climate entity's control-relevant state: everything the frontend's more-info
/// dialog offers, parsed from the entity's state and attributes.
///
/// Fields are mutable so control UIs can overlay optimistic values (e.g. a target temperature the
/// user just picked that the server hasn't echoed back yet) on top of a fresh snapshot.
public struct ClimateControlState {
    // Defaults mirror Home Assistant core's climate entity defaults.
    public static let defaultMinTemperature = 7.0
    public static let defaultMaxTemperature = 35.0
    public static let defaultTemperatureStep = 0.5
    public static let defaultMinHumidity = 30.0
    public static let defaultMaxHumidity = 99.0
    /// Tap-sized humidity step for the +/- controls on CarPlay and the watch; the frontend uses a
    /// slider, which doesn't translate to those surfaces.
    public static let humidityStep = 5.0

    /// The entity's state is its active HVAC mode (e.g. `heat`, `cool`, `off`).
    public var hvacMode: String
    public var hvacModes: [String]
    public var hvacAction: String?
    public var currentTemperature: Double?
    public var targetTemperature: Double?
    public var targetTemperatureLow: Double?
    public var targetTemperatureHigh: Double?
    public var minTemperature: Double
    public var maxTemperature: Double
    public var temperatureStep: Double
    public var fanMode: String?
    public var fanModes: [String]
    public var swingMode: String?
    public var swingModes: [String]
    public var swingHorizontalMode: String?
    public var swingHorizontalModes: [String]
    public var presetMode: String?
    public var presetModes: [String]
    public var currentHumidity: Double?
    public var targetHumidity: Double?
    public var minHumidity: Double
    public var maxHumidity: Double
    public var features: ClimateEntityFeature

    public init(state: String, attributes: [String: Any]) {
        self.hvacMode = state
        self.hvacModes = Self.strings(from: attributes["hvac_modes"])
        self.hvacAction = attributes["hvac_action"] as? String
        self.currentTemperature = Self.double(from: attributes["current_temperature"])
        self.targetTemperature = Self.double(from: attributes["temperature"])
        self.targetTemperatureLow = Self.double(from: attributes["target_temp_low"])
        self.targetTemperatureHigh = Self.double(from: attributes["target_temp_high"])
        self.minTemperature = Self.double(from: attributes["min_temp"]) ?? Self.defaultMinTemperature
        self.maxTemperature = Self.double(from: attributes["max_temp"]) ?? Self.defaultMaxTemperature
        self.temperatureStep = Self.double(from: attributes["target_temp_step"]) ?? Self.defaultTemperatureStep
        self.fanMode = attributes["fan_mode"] as? String
        self.fanModes = Self.strings(from: attributes["fan_modes"])
        self.swingMode = attributes["swing_mode"] as? String
        self.swingModes = Self.strings(from: attributes["swing_modes"])
        self.swingHorizontalMode = attributes["swing_horizontal_mode"] as? String
        self.swingHorizontalModes = Self.strings(from: attributes["swing_horizontal_modes"])
        self.presetMode = attributes["preset_mode"] as? String
        self.presetModes = Self.strings(from: attributes["preset_modes"])
        self.currentHumidity = Self.double(from: attributes["current_humidity"])
        self.targetHumidity = Self.double(from: attributes["humidity"])
        self.minHumidity = Self.double(from: attributes["min_humidity"]) ?? Self.defaultMinHumidity
        self.maxHumidity = Self.double(from: attributes["max_humidity"]) ?? Self.defaultMaxHumidity
        self.features = ClimateEntityFeature(attributes: attributes)
    }

    public init(entity: HAEntity) {
        self.init(state: entity.state, attributes: entity.attributes.dictionary)
    }

    // MARK: - Capabilities

    public var supportsTargetTemperature: Bool {
        features.contains(.targetTemperature)
    }

    public var supportsTargetTemperatureRange: Bool {
        features.contains(.targetTemperatureRange)
    }

    public var supportsTargetHumidity: Bool {
        features.contains(.targetHumidity)
    }

    public var supportsFanMode: Bool {
        features.contains(.fanMode) && !fanModes.isEmpty
    }

    public var supportsSwingMode: Bool {
        features.contains(.swingMode) && !swingModes.isEmpty
    }

    public var supportsSwingHorizontalMode: Bool {
        features.contains(.swingHorizontalMode) && !swingHorizontalModes.isEmpty
    }

    public var supportsPresetMode: Bool {
        features.contains(.presetMode) && !presetModes.isEmpty
    }

    public var supportsHvacModes: Bool {
        !hvacModes.isEmpty
    }

    // MARK: - Value helpers

    public func clampTemperature(_ value: Double) -> Double {
        min(max(value, minTemperature), maxTemperature)
    }

    public func clampHumidity(_ value: Double) -> Double {
        min(max(value, minHumidity), maxHumidity)
    }

    /// One-line summary for list rows: the localized mode plus the current temperature,
    /// e.g. "Heat · 21.5°".
    public var stateSummary: String {
        // Unavailable/unknown aren't HVAC modes; use their existing localized titles on their own.
        if [Domain.State.unavailable.rawValue, Domain.State.unknown.rawValue].contains(hvacMode) {
            return FrontendStrings.getDefaultStateLocalizedTitle(state: hvacMode) ?? hvacMode.leadingCapitalized
        }
        var parts = [ClimateHvacMode.localizedTitle(forMode: hvacMode)]
        if let currentTemperature {
            parts.append(Self.formatTemperature(currentTemperature))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Formatting

    /// Formats a temperature with a bare degree sign: climate attributes don't carry the unit, and
    /// the value is already in the server's configured unit system.
    public static func formatTemperature(_ value: Double) -> String {
        "\(formatNumber(value))°"
    }

    public static func formatHumidity(_ value: Double) -> String {
        "\(formatNumber(value))%"
    }

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Humanized display name for raw mode values the app has no localized string for
    /// (fan/swing/preset modes are free-form, integration-defined strings).
    public static func displayName(forMode mode: String) -> String {
        mode.replacingOccurrences(of: "_", with: " ").leadingCapitalized
    }

    // MARK: - Attribute parsing

    private static func double(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func strings(from value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        return (value as? [Any])?.compactMap { $0 as? String } ?? []
    }
}
