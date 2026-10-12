#if !os(watchOS)
import HAIconic
import SwiftUI

/// The battery level beside a vacuum's or mower's last-changed time: the percentage and a battery
/// glyph filled to match.
///
/// Frontend counterpart: `_renderBattery` in `more-info-vacuum` and `more-info-lawn_mower`, drawn
/// with `ha-battery-icon`. Split out because both dialogs render it identically.
public struct HAMoreInfoBattery: View {
    @Environment(\.locale) private var locale
    private let level: Double?
    private let isCharging: Bool
    private let isLow: Bool

    /// - Parameters:
    ///   - level: 0–100, or `nil` when the device reports only low/not-low through a binary sensor,
    ///     which shows the glyph alone.
    ///   - isLow: What that binary sensor reports. Ignored when there is a level, which says it
    ///     already.
    public init(level: Double?, isCharging: Bool = false, isLow: Bool = false) {
        self.level = level
        self.isCharging = isCharging
        self.isLow = isLow
    }

    private var icon: MaterialDesignIcons {
        guard let level else {
            if isCharging {
                return .batteryChargingIcon
            }
            return isLow ? .batteryAlertIcon : .batteryIcon
        }
        let tens = Int((Swift.min(Swift.max(level, 0), 100) / 10).rounded())
        if isCharging {
            return switch tens {
            case 0, 1: .batteryCharging10Icon
            case 2: .batteryCharging20Icon
            case 3: .batteryCharging30Icon
            case 4: .batteryCharging40Icon
            case 5: .batteryCharging50Icon
            case 6: .batteryCharging60Icon
            case 7: .batteryCharging70Icon
            case 8: .batteryCharging80Icon
            case 9: .batteryCharging90Icon
            default: .batteryCharging100Icon
            }
        }
        return switch tens {
        case 0: .batteryOutlineIcon
        case 1: .battery10Icon
        case 2: .battery20Icon
        case 3: .battery30Icon
        case 4: .battery40Icon
        case 5: .battery50Icon
        case 6: .battery60Icon
        case 7: .battery70Icon
        case 8: .battery80Icon
        case 9: .battery90Icon
        default: .batteryIcon
        }
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.micro) {
            if let level {
                Text((level / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                    .font(.system(size: 14))
            }
            MaterialDesignIconsImage(icon: icon, size: 20)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAMoreInfoBattery(level: 84)
        HAMoreInfoBattery(level: 42, isCharging: true)
        HAMoreInfoBattery(level: nil)
        HAMoreInfoBattery(level: nil, isLow: true)
    }
    .padding()
}

extension HAMoreInfoBattery: FrontendComponent {
    public static var frontendComponentName: String { "ha-battery-icon" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
