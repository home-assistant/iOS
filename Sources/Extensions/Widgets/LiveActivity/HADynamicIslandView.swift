import ActivityKit
import Shared
import SwiftUI
import WidgetKit

// MARK: - DynamicIsland builder

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
@available(iOS 16.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            HADynamicIslandIconView(slug: state.icon, color: state.color, size: 24)
                .padding(.leading, DesignSystem.Spaces.half)
        }
        DynamicIslandExpandedRegion(.center) {
            Text(attributes.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
            HAExpandedTrailingView(state: state)
                .padding(.trailing, DesignSystem.Spaces.half)
        }
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedBottomView(state: state)
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.bottom, DesignSystem.Spaces.half)
        }
    } compactLeading: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 16)
            .padding(.leading, DesignSystem.Spaces.half)
    } compactTrailing: {
        HACompactTrailingView(state: state)
            .padding(.trailing, DesignSystem.Spaces.half)
    } minimal: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 14)
    }
}

// MARK: - Icon view

@available(iOS 16.2, *)
struct HADynamicIslandIconView: View {
    let slug: String?
    let color: String?
    let size: CGFloat

    /// Hex string for Home Assistant brand blue — used for UIColor(hex:) fallback.
    private static let haBlueHex = "#03A9F4"

    var body: some View {
        if let slug {
            // UIColor(hex:) from Shared handles nil/CSS names/3-6-8 digit hex; non-failable.
            let uiColor = UIColor(hex: color ?? Self.haBlueHex)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: slug)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: size, height: size),
                color: uiColor
            ))
            .resizable()
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Compact trailing

@available(iOS 16.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    /// Maximum width for compact trailing text to prevent overflow in the Dynamic Island.
    private static let compactTrailingMaxWidth: CGFloat = 50

    var body: some View {
        if state.chronometer == true, let end = state.countdownEnd {
            Text(timerInterval: Date.now ... end, countsDown: true)
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(maxWidth: Self.compactTrailingMaxWidth)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: Self.compactTrailingMaxWidth)
        } else if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Expanded trailing

@available(iOS 16.2, *)
struct HAExpandedTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Expanded bottom

@available(iOS 16.2, *)
struct HAExpandedBottomView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            if state.chronometer == true, let end = state.countdownEnd {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            if let fraction = state.progressFraction {
                ProgressView(value: fraction)
                    .tint(accentColor)
            }
        }
    }

    /// Accent color from ContentState, fallback to Home Assistant primary blue.
    private var accentColor: Color {
        if let hex = state.color {
            return Color(hex: hex)
        }
        return .haPrimary
    }
}
