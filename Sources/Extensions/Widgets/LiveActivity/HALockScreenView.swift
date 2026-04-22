#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Lock Screen (and StandBy) view for a Home Assistant Live Activity.
///
/// The system hard-truncates at 160 points height — padding counts against this limit.
/// Keep layout tight and avoid decorative spacing.
@available(iOS 17.2, *)
struct HALockScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    /// Icon size for the MDI icon in the header row.
    private static let iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                iconContainer

                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(attributes.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)

                    if state.chronometer == true, let end = state.countdownEnd {
                        Text(timerInterval: Date.now ... end, countsDown: true)
                            .font(.title3.monospacedDigit().weight(.medium))
                            .foregroundStyle(secondaryTextColor)
                            .contentTransition(.numericText(countsDown: true))
                    } else {
                        Text(state.message)
                            .font(.body)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                trailingValue
            }

            if let fraction = state.progressFraction {
                HAActivityProgressBar(
                    fraction: fraction,
                    fillColor: accentColor,
                    trackColor: trackColor,
                    height: 10
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.vertical, DesignSystem.Spaces.two)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iconContainer: some View {
        if state.icon != nil {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.2 : 0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                            .strokeBorder(accentColor.opacity(colorScheme == .dark ? 0.3 : 0.18))
                    }

                iconView
            }
            .frame(width: 48, height: 48)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconSlug = state.icon {
            // UIColor(hex:) from Shared handles CSS names and 3/6/8-digit hex; non-failable.
            let uiColor = HAActivityVisualStyle.uiColor(from: state.color)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: iconSlug)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: Self.iconSize, height: Self.iconSize),
                color: uiColor
            ))
            .resizable()
            .frame(width: Self.iconSize, height: Self.iconSize)
        }
    }

    @ViewBuilder
    private var trailingValue: some View {
        if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.headline.monospacedDigit())
                .foregroundStyle(primaryTextColor)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.headline)
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    /// Accent color from ContentState, fallback to Home Assistant primary blue.
    private var accentColor: Color {
        HAActivityVisualStyle.color(from: state.color)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.72)
    }

    private var trackColor: Color {
        colorScheme == .dark ? .white.opacity(0.14) : .black.opacity(0.08)
    }
}

@available(iOS 17.2, *)
struct HAActivityProgressBar: View {
    let fraction: Double
    let fillColor: Color
    let trackColor: Color
    let height: CGFloat

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = clampedFraction == 0 ? 0 : max(geometry.size.width * clampedFraction, height)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                fillColor.opacity(0.9),
                                fillColor,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(Text(HAActivityVisualStyle.accessibilityPercentString(for: clampedFraction)))
    }
}

enum HAActivityVisualStyle {
    /// Hex string for Home Assistant brand blue — used for UIColor(hex:) fallback.
    private static let haBlueHex = "#03A9F4"

    static func uiColor(from color: String?) -> UIColor {
        UIColor(hex: color ?? haBlueHex)
    }

    static func color(from color: String?) -> Color {
        Color(uiColor: uiColor(from: color))
    }

    static func percentString(for fraction: Double) -> String {
        "\(roundedPercent(for: fraction))%"
    }

    static func accessibilityPercentString(for fraction: Double) -> String {
        "\(roundedPercent(for: fraction)) percent"
    }

    private static func roundedPercent(for fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }
}
#endif
