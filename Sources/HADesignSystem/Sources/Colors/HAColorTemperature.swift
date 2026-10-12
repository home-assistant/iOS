import Foundation
import SwiftUI

/// The colour a white light of a given temperature appears, and the warm-to-cool gradient a colour
/// temperature slider is painted with.
///
/// Frontend counterpart: `temperature2rgb` in `common/color/convert-light-color.ts` and
/// `generateColorTemperatureGradient` in `light-color-temp-picker.ts`. Kept apart from the drawing so
/// the curve can be tested.
public enum HAColorTemperature {
    /// The frontend's defaults when a light reports no range of its own.
    public static let defaultMinKelvin: Double = 2000
    public static let defaultMaxKelvin: Double = 6500

    /// The red, green and blue, each 0–255, that `kelvin` looks like.
    public static func rgb(kelvin: Double) -> (red: Int, green: Int, blue: Int) {
        let value = kelvin / 100
        let red: Double = value <= 66 ? 255 : 329.698727446 * pow(value - 60, -0.1332047592)
        let green: Double = value <= 66
            ? 99.4708025861 * log(value) - 161.1195681661
            : 288.1221695283 * pow(value - 60, -0.0755148492)
        let blue: Double = if value >= 66 {
            255
        } else if value <= 19 {
            0
        } else {
            138.5177312231 * log(value - 10) - 305.0447927307
        }
        return (clamped(red), clamped(green), clamped(blue))
    }

    public static func color(kelvin: Double) -> Color {
        let rgb = rgb(kelvin: kelvin)
        return Color(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }

    /// Eleven evenly spaced stops from `minKelvin` to `maxKelvin`.
    public static func gradient(minKelvin: Double, maxKelvin: Double) -> Gradient {
        let count = 10
        let step = (maxKelvin - minKelvin) / Double(count)
        return Gradient(stops: (0 ... count).map { index in
            Gradient.Stop(
                color: color(kelvin: minKelvin + step * Double(index)),
                location: Double(index) / Double(count)
            )
        })
    }

    private static func clamped(_ value: Double) -> Int {
        Int(Swift.min(Swift.max(value, 0), 255).rounded())
    }
}
