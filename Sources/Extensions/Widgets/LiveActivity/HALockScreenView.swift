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

    /// Icon size for the MDI icon in the header row.
    private static let iconSize: CGFloat = 20

    /// Hex string for Home Assistant brand blue — used for UIColor(hex:) fallback.
    private static let haBlueHex = "#03A9F4"

    /// Subdued white for secondary text (timer/message body).
    private static let secondaryWhite: Color = .white.opacity(0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            // Header row: icon + title
            HStack(spacing: DesignSystem.Spaces.one) {
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
                    .foregroundStyle(Self.secondaryWhite)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(Self.secondaryWhite)
                    .lineLimit(2)
            }

            // Progress bar (only when progress data is present)
            if let fraction = state.progressFraction {
                ProgressView(value: fraction)
                    .tint(accentColor)
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.vertical, DesignSystem.Spaces.oneAndHalf)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iconView: some View {
        if let iconSlug = state.icon {
            // UIColor(hex:) from Shared handles CSS names and 3/6/8-digit hex; non-failable.
            let uiColor = UIColor(hex: state.color ?? Self.haBlueHex)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: iconSlug)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: Self.iconSize, height: Self.iconSize),
                color: uiColor
            ))
            .resizable()
            .frame(width: Self.iconSize, height: Self.iconSize)
        }
    }

    // MARK: - Helpers

    /// Accent color from ContentState, fallback to Home Assistant primary blue.
    private var accentColor: Color {
        if let hex = state.color {
            return Color(hex: hex)
        }
        return .haPrimary
    }
}
