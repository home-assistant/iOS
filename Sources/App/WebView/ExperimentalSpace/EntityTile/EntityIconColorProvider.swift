import Foundation
import Shared
import SwiftUI

enum EntityIconColorProvider {
    static func iconColor(
        state: String,
        colorMode: String?,
        rgbColor: [Int]?,
        hsColor: [Double]?
    ) -> Color {
        guard state == Domain.State.on.rawValue else {
            return .secondary
        }

        // Check color_mode first if available to prioritize the correct attribute
        if let colorMode {
            switch colorMode {
            case "rgb", "rgbw", "rgbww":
                if let rgb = rgbColor, rgb.count == 3 {
                    return Color(
                        red: Double(rgb[0]) / 255.0,
                        green: Double(rgb[1]) / 255.0,
                        blue: Double(rgb[2]) / 255.0
                    )
                }
            case "hs":
                if let hs = hsColor, hs.count == 2 {
                    return Color(hue: hs[0] / 360.0, saturation: hs[1] / 100.0, brightness: 1.0)
                }
            case "xy", "color_temp":
                // Home Assistant usually provides rgb_color approximation for xy and color_temp
                if let rgb = rgbColor, rgb.count == 3 {
                    return Color(
                        red: Double(rgb[0]) / 255.0,
                        green: Double(rgb[1]) / 255.0,
                        blue: Double(rgb[2]) / 255.0
                    )
                }
            default:
                break
            }
        }

        // Fallback or if color_mode is missing
        if let rgb = rgbColor, rgb.count == 3 {
            return Color(
                red: Double(rgb[0]) / 255.0,
                green: Double(rgb[1]) / 255.0,
                blue: Double(rgb[2]) / 255.0
            )
        }

        if let hs = hsColor, hs.count == 2 {
            return Color(hue: hs[0] / 360.0, saturation: hs[1] / 100.0, brightness: 1.0)
        }

        return .yellow
    }
}
