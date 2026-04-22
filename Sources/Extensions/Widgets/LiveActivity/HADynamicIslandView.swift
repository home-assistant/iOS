#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

// MARK: - DynamicIsland builder

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
@available(iOS 17.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            HADynamicIslandIconContainerView(slug: state.icon, color: state.color, size: 28)
                .padding(.leading, DesignSystem.Spaces.one)
        }
        DynamicIslandExpandedRegion(.center) {
            Text(attributes.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        DynamicIslandExpandedRegion(.trailing) {
            HAExpandedTrailingView(state: state)
                .padding(.trailing, DesignSystem.Spaces.one)
        }
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedBottomView(state: state)
                .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                .padding(.bottom, DesignSystem.Spaces.one)
        }
    } compactLeading: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 18)
            .padding(.leading, DesignSystem.Spaces.half)
    } compactTrailing: {
        HACompactTrailingView(state: state)
            .padding(.trailing, DesignSystem.Spaces.half)
    } minimal: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 16)
    }
}

// MARK: - Icon view

@available(iOS 17.2, *)
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

@available(iOS 17.2, *)
struct HADynamicIslandIconContainerView: View {
    let slug: String?
    let color: String?
    let size: CGFloat

    var body: some View {
        if slug != nil {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                    .fill(accentColor.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.28))
                    }

                HADynamicIslandIconView(slug: slug, color: color, size: size)
            }
            .frame(width: 44, height: 44)
        }
    }

    private var accentColor: Color {
        if let color {
            return Color(hex: color)
        }
        return .haPrimary
    }
}

// MARK: - Compact trailing

@available(iOS 17.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    /// Fixed width for the countdown timer text in compact trailing.
    /// 44 pt fits "M:SS" at caption2 size and prevents the Dynamic Island from
    /// squeezing the slot narrower than the text needs.
    private static let compactTrailingTimerWidth: CGFloat = 44
    /// Maximum width for non-timer compact trailing content (criticalText, progress %).
    private static let compactTrailingMaxWidth: CGFloat = 50

    var body: some View {
        if state.chronometer == true, let end = state.countdownEnd {
            Text(timerInterval: Date.now ... end, countsDown: true)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .frame(width: Self.compactTrailingTimerWidth)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: Self.compactTrailingMaxWidth)
        } else if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Expanded trailing

@available(iOS 17.2, *)
struct HAExpandedTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Expanded bottom

@available(iOS 17.2, *)
struct HAExpandedBottomView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            if state.chronometer == true, let end = state.countdownEnd {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Text(state.message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
            }

            if let fraction = state.progressFraction {
                HAActivityProgressBar(
                    fraction: fraction,
                    fillColor: accentColor,
                    trackColor: .white.opacity(0.16),
                    height: 8
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Accent color from ContentState, fallback to Home Assistant primary blue.
    private var accentColor: Color {
        if let hex = state.color {
            return Color(hex: hex)
        }
        return .haPrimary
    }
}
#endif
