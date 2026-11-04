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

    /// Icon size for the MDI icon in the header row.
    private static let iconSize: CGFloat = 28

    /// Lets the trailing value (e.g. "100%") shrink to fit on one line instead of
    /// wrapping the "%" onto a second line when horizontal space is tight.
    private static let trailingValueMinimumScaleFactor: CGFloat = 0.7

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

            if let fraction = state.progressBarFillFraction {
                HAActivityProgressBar(
                    fraction: fraction,
                    fillColor: barColor,
                    trackColor: trackColor,
                    height: 10
                )
            } else if state.chronometer == true, let end = state.countdownEnd {
                HAActivityTimerProgressBar(
                    start: state.chronometerStart,
                    end: end,
                    tint: barColor,
                    direction: state.resolvedProgressBarDirection
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
                    .fill(accentColor.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.28))
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
        if let critical = state.criticalText {
            Text(critical)
                .font(.headline)
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(Self.trailingValueMinimumScaleFactor)
        } else if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.headline.monospacedDigit())
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(Self.trailingValueMinimumScaleFactor)
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

    /// Explicit `text_color` or auto-contrast against an explicit `background_color`, else nil so
    /// primary/secondary text fall back to the adaptive system colors. Those stay legible on the
    /// transparent Lock Screen material without us inspecting the color scheme.
    private var resolvedForeground: Color? {
        HAActivityVisualStyle.foregroundColor(textColor: state.textColor, onBackground: state.backgroundColor)
    }

    private var primaryTextColor: Color {
        resolvedForeground ?? .primary
    }

    private var secondaryTextColor: Color {
        resolvedForeground?.opacity(0.8) ?? .secondary
    }

    private var trackColor: Color {
        (resolvedForeground ?? .primary).opacity(0.12)
    }
}

enum HAActivityVisualStyle {
    /// Hex string for Home Assistant brand blue — used for UIColor(hex:) fallback.
    private static let haBlueHex = "#03A9F4"
    private static let supplementalBackgroundHex = "#1C1C1E"

    static let defaultSupplementalForegroundColor = Color.white

    /// Treats nil, empty, or whitespace-only as "unset" so the caller's default applies — an empty
    /// `background_color`/`text_color` would otherwise parse to transparent via UIColor(hex:).
    static func normalized(_ hex: String?) -> String? {
        let trimmed = hex?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    static func uiColor(from color: String?) -> UIColor {
        UIColor(hex: color ?? haBlueHex)
    }

    /// Explicit `background_color`, else `.clear` so the Lock Screen's own translucent,
    /// appearance-adaptive material shows through. A nil tint makes ActivityKit fall back to an
    /// opaque (black) default instead, so `.clear` is what actually yields a transparent background.
    static func backgroundColor(from hex: String?) -> Color {
        guard let hex = normalized(hex) else { return .clear }
        return Color(uiColor: UIColor(hex: hex))
    }

    static func supplementalBackgroundColor(from hex: String?) -> Color {
        Color(uiColor: UIColor(hex: normalized(hex) ?? supplementalBackgroundHex))
    }

    /// Whether light text reads best on the given opaque background hex, by Rec. 601 luma.
    static func prefersLightText(onBackground hex: String) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(hex: hex).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (0.299 * red + 0.587 * green + 0.114 * blue) < 0.6
    }

    /// Foreground that can be resolved without the render environment:
    ///   - explicit `text_color`, else
    ///   - a black/white auto-contrast against an opaque `background_color`.
    /// Nil when neither applies (including a fully transparent `background_color` such as
    /// "clear"/"transparent"/an alpha-0 hex), so the caller falls back to the adaptive system
    /// color (`.primary`), which stays legible on the transparent Lock Screen material.
    static func foregroundColor(textColor: String?, onBackground backgroundHex: String?) -> Color? {
        if let textColor = normalized(textColor) {
            return Color(uiColor: UIColor(hex: textColor))
        }
        guard let backgroundHex = normalized(backgroundHex) else { return nil }
        var alpha: CGFloat = 0
        UIColor(hex: backgroundHex).getRed(nil, green: nil, blue: nil, alpha: &alpha)
        guard alpha > 0 else { return nil }
        return prefersLightText(onBackground: backgroundHex) ? .white : .black
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
