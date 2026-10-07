import Foundation
import HAKit

/// What a light entity can do beyond turning on and off, parsed from its state attributes.
///
/// Home Assistant advertises light capabilities through `supported_color_modes`: every mode other
/// than `onoff` implies the light can dim, and `color_temp` additionally means its white
/// temperature is tunable. List UIs (the watch) use this to decide whether tapping a light opens
/// its controls screen or just toggles it.
public struct LightCapabilities: Equatable {
    /// A value of `supported_color_modes`, as defined by Home Assistant's light entity model.
    public enum ColorMode: String {
        case onoff
        case brightness
        case colorTemp = "color_temp"
        case hs
        case xy
        case rgb
        case rgbw
        case rgbww
        case white

        /// Every mode except plain on/off supports brightness.
        public var supportsBrightness: Bool {
            self != .onoff
        }

        /// Modes that can render an arbitrary color (not just white temperature).
        public var supportsColor: Bool {
            [.hs, .xy, .rgb, .rgbw, .rgbww].contains(self)
        }
    }

    /// Home Assistant's own defaults for lights that don't report a kelvin range
    /// (min_mireds 153 / max_mireds 500, rounded to friendly values).
    public static let defaultMinColorTempKelvin: Double = 2000
    public static let defaultMaxColorTempKelvin: Double = 6500

    public let supportsBrightness: Bool
    public let supportsColorTemp: Bool
    /// Whether the light can render arbitrary colors (hs/xy/rgb modes) — e.g. Hue color bulbs.
    public let supportsColor: Bool
    /// Current brightness as 0–100, derived from the 0–255 `brightness` attribute. Nil when the
    /// light is off (Home Assistant drops the attribute) or doesn't dim.
    public let brightnessPercentage: Double?
    /// Current color temperature in kelvin; nil when the light is off or not in color temp mode.
    public let colorTempKelvin: Double?
    public let minColorTempKelvin: Double
    public let maxColorTempKelvin: Double

    /// Whether the light offers anything to control beyond toggling — the gate for showing a
    /// dedicated controls screen instead of treating a tap as a toggle.
    public var hasAdjustableControls: Bool {
        supportsBrightness || supportsColorTemp || supportsColor
    }

    public init(entity: HAEntity) {
        self.init(attributes: entity.attributes.dictionary)
    }

    public init(attributes: [String: Any]) {
        let modes = (attributes["supported_color_modes"] as? [String] ?? [])
            .compactMap(ColorMode.init(rawValue:))

        if modes.isEmpty {
            // Very old servers (pre-2021) don't report color modes; the presence of the value
            // attributes is the only remaining hint of what the light can do.
            self.supportsBrightness = attributes["brightness"] != nil
            self.supportsColorTemp = attributes["color_temp_kelvin"] != nil
            self.supportsColor = attributes["hs_color"] != nil
        } else {
            self.supportsBrightness = modes.contains { $0.supportsBrightness }
            self.supportsColorTemp = modes.contains(.colorTemp)
            self.supportsColor = modes.contains { $0.supportsColor }
        }

        if supportsBrightness, let brightness = Self.double(from: attributes["brightness"]) {
            self.brightnessPercentage = (brightness / 255 * 100).rounded()
        } else {
            self.brightnessPercentage = nil
        }
        self.colorTempKelvin = Self.double(from: attributes["color_temp_kelvin"])
        self.minColorTempKelvin = Self.double(from: attributes["min_color_temp_kelvin"])
            ?? Self.defaultMinColorTempKelvin
        self.maxColorTempKelvin = Self.double(from: attributes["max_color_temp_kelvin"])
            ?? Self.defaultMaxColorTempKelvin
    }

    private static func double(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }
}
