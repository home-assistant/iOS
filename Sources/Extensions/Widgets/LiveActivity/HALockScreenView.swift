import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Lock Screen (and StandBy) view for a Home Assistant Live Activity.
///
/// The system hard-truncates at 160 points height — padding counts against this limit.
/// Keep layout tight and avoid decorative spacing.
@available(iOS 16.2, *)
struct HALockScreenView: View {
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: icon + title
            HStack(spacing: 8) {
                iconView
                Text(attributes.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            // Body: timer or message
            if state.chronometer == true, let end = state.countdownEnd {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            } else {
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            // Progress bar (only when progress data is present)
            if let fraction = state.progressFraction {
                ProgressView(value: fraction)
                    .tint(accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iconView: some View {
        if let iconSlug = state.icon,
           let mdiIcon = MaterialDesignIcons(serversideValueNamed: iconSlug) {
            let uiColor = UIColor(hex: state.color ?? "#03A9F4") ?? .white
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: 20, height: 20),
                color: uiColor
            ))
            .resizable()
            .frame(width: 20, height: 20)
        }
    }

    // MARK: - Helpers

    /// Parse hex color from ContentState, fallback to Home Assistant blue.
    private var accentColor: Color {
        guard let hex = state.color else {
            return Color(hex: "#03A9F4") // HA blue
        }
        return Color(hex: hex)
    }
}

// MARK: - Color(hex:) + UIColor(hex:) extensions

extension Color {
    /// Initialize from a hex string like `#RRGGBB` or `#RRGGBBAA`.
    /// Pre-parsing here prevents hex string work in every render pass.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RRGGBB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RRGGBBAA
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.2, *)
#Preview("Lock Screen — Progress", as: .content, using: HALiveActivityAttributes(tag: "washer", title: "Washing Machine")) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "45 minutes remaining",
        criticalText: "45 min",
        progress: 2700,
        progressMax: 3600,
        icon: "mdi:washing-machine",
        color: "#2196F3"
    )
    HALiveActivityAttributes.ContentState(
        message: "Cycle complete!",
        progress: 3600,
        progressMax: 3600,
        icon: "mdi:check-circle",
        color: "#4CAF50"
    )
}

@available(iOS 16.2, *)
#Preview("Lock Screen — Chronometer", as: .content, using: HALiveActivityAttributes(tag: "timer", title: "Kitchen Timer")) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "Timer running",
        chronometer: true,
        countdownEnd: Date().addingTimeInterval(300),
        icon: "mdi:timer",
        color: "#FF9800"
    )
}
#endif
