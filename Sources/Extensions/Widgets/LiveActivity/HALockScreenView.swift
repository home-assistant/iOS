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
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    /// Drives the light/dark styling when we render on the system's adaptive background
    /// (i.e. no explicit `background_color`).
    @Environment(\.colorScheme) private var colorScheme

    /// Icon size for the MDI icon in the header row.
    private static let iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                iconContainer

                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(state.title ?? attributes.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)

                    if state.chronometer == true, let end = state.countdownEnd {
                        HAActivityChronometerText(end: end, start: state.chronometerStart)
                            .font(.title3.monospacedDigit().weight(.medium))
                            .foregroundStyle(secondaryTextColor)
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
                    fillColor: barColor,
                    trackColor: trackColor,
                    height: 10
                )
            } else if state.chronometer == true, let end = state.countdownEnd {
                HAActivityTimerProgressBar(start: state.chronometerStart, end: end, tint: barColor)
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
                    .fill(accentColor.opacity(useLightText ? 0.2 : 0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                            .strokeBorder(accentColor.opacity(useLightText ? 0.3 : 0.18))
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

    /// Progress bar tint: `progress_bar_color`, else the icon color, else HA blue.
    private var barColor: Color {
        HAActivityVisualStyle.color(from: state.progressBarColor ?? state.color)
    }

    /// Whether light-on-dark styling applies: driven by an explicit `background_color`'s luma,
    /// else by the current appearance when we render on the system's adaptive background.
    private var useLightText: Bool {
        if let background = HAActivityVisualStyle.normalized(state.backgroundColor) {
            return HAActivityVisualStyle.prefersLightText(onBackground: background)
        }
        return colorScheme == .dark
    }

    /// Explicit `text_color` or auto-contrast against an explicit `background_color`, else nil to
    /// defer to the adaptive system color so text stays legible on the default background.
    private var resolvedForeground: Color? {
        HAActivityVisualStyle.foregroundColor(textColor: state.textColor, onBackground: state.backgroundColor)
    }

    private var primaryTextColor: Color {
        resolvedForeground ?? .primary
    }

    private var secondaryTextColor: Color {
        if let resolvedForeground {
            return resolvedForeground.opacity(useLightText ? 0.8 : 0.72)
        }
        return .secondary
    }

    private var trackColor: Color {
        (resolvedForeground ?? .primary).opacity(useLightText ? 0.14 : 0.08)
    }
}

enum HAActivityVisualStyle {
    /// Hex string for Home Assistant brand blue — used for UIColor(hex:) fallback.
    private static let haBlueHex = "#03A9F4"

    /// Treats nil, empty, or whitespace-only as "unset" so the caller's default applies — an empty
    /// `background_color`/`text_color` would otherwise parse to transparent via UIColor(hex:).
    static func normalized(_ hex: String?) -> String? {
        let trimmed = hex?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    static func uiColor(from color: String?) -> UIColor {
        UIColor(hex: color ?? haBlueHex)
    }

    /// Explicit `background_color`, or nil to let the system render its default translucent,
    /// appearance-adaptive Live Activity background (Apple's recommended default).
    static func backgroundColor(from hex: String?) -> Color? {
        guard let hex = normalized(hex) else { return nil }
        return Color(uiColor: UIColor(hex: hex))
    }

    /// Whether light text reads best on the given opaque background hex, by Rec. 601 luma.
    static func prefersLightText(onBackground hex: String) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(hex: hex).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (0.299 * red + 0.587 * green + 0.114 * blue) < 0.6
    }

    /// Foreground that can be resolved without the render environment:
    ///   - explicit `text_color`, else
    ///   - a black/white auto-contrast against an explicit `background_color`.
    /// Nil when neither is set, so the caller falls back to the adaptive system color (`.primary`),
    /// which stays legible on the system's translucent background in both light and dark mode.
    static func foregroundColor(textColor: String?, onBackground backgroundHex: String?) -> Color? {
        if let textColor = normalized(textColor) {
            return Color(uiColor: UIColor(hex: textColor))
        }
        if let backgroundHex = normalized(backgroundHex) {
            return prefersLightText(onBackground: backgroundHex) ? .white : .black
        }
        return nil
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
