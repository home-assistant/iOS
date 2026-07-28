import Foundation
import HADesignSystem
import SwiftUI

public enum EntityIconColorProvider {
    /// Frontend state palette (`color.globals.ts` in home-assistant/frontend), for states that
    /// have no domain accent or live color of their own.
    public static let activeColor = Color(hex: "#FFC107") // --state-active-color (amber)
    public static let lockLockedColor = Color(hex: "#4CAF50") // --state-lock-locked-color (green)
    public static let lockUnlockedColor = Color(hex: "#F44336") // --state-lock-unlocked/jammed-color (red)
    public static let lockTransitionColor = Color(hex: "#FF9800") // --state-lock-locking/unlocking-color (orange)

    public static func iconColor(
        domain: Domain,
        state: String,
        colorMode: String?,
        rgbColor: [Int]?,
        hsColor: [Double]?
    ) -> Color {
        // Locks carry their own per-state palette in the frontend; match it before the generic
        // active/inactive handling ("locked" isn't an active state and would come out gray).
        if domain == .lock, let lockState = Domain.State(rawValue: state),
           let lockColor = lockColor(for: lockState) {
            return lockColor
        }

        guard Domain.activeStates.map(\.rawValue).contains(state) else {
            if Domain.problemStates.map(\.rawValue).contains(state) {
                return .red
            } else {
                return .gray
            }
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

        return domain.accentColor
    }

    private static func lockColor(for state: Domain.State) -> Color? {
        switch state {
        case .locked:
            return lockLockedColor
        case .unlocked, .jammed, .open:
            return lockUnlockedColor
        case .locking, .unlocking, .opening:
            return lockTransitionColor
        default:
            // Unknown/unavailable fall through to the generic handling.
            return nil
        }
    }
}

public extension Domain {
    var accentColor: Color {
        switch self {
        case .light:
            Color.Domain.light
        case .switch:
            Color.Domain.switch
        case .fan:
            Color.Domain.fan
        case .cover:
            Color.Domain.cover
        default:
            // The frontend's generic active color (--state-active-color).
            EntityIconColorProvider.activeColor
        }
    }
}
