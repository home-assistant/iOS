#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.2, *)
struct HALiveActivityCompactView: View {
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    private static let iconSize: CGFloat = 18
    private static let trailingValueMinimumScaleFactor: CGFloat = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                icon
                VStack(alignment: .leading, spacing: .zero) {
                    Text(state.title ?? attributes.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                    Text(state.message)
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                trailingValue
            }

            secondaryContent
                .padding(.top, DesignSystem.Spaces.half)
        }
        .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
        .padding(.vertical, DesignSystem.Spaces.one)
    }

    @ViewBuilder
    private var icon: some View {
        if let slug = state.icon {
            let uiColor = HAActivityVisualStyle.uiColor(from: state.color)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: slug)
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
        if let value = state.cardTrailingValue {
            switch value {
            case let .criticalText(critical):
                Text(critical)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(Self.trailingValueMinimumScaleFactor)
            case let .progressPercent(fraction):
                Text(HAActivityVisualStyle.percentString(for: fraction))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(Self.trailingValueMinimumScaleFactor)
            }
        }
    }

    /// The progress bar, carrying the percentage `critical_text` displaced from the trailing slot.
    /// The bar keeps the whole row to itself when nothing was displaced, so the common
    /// progress-only card is laid out exactly as before.
    @ViewBuilder
    private var secondaryContent: some View {
        if let fraction = state.progressBarFillFraction {
            if let percent = state.displacedProgressPercent {
                HStack(spacing: DesignSystem.Spaces.half) {
                    progressBar(fraction: fraction)
                    Text(HAActivityVisualStyle.percentString(for: percent))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        // The bar already reports the same percentage as its accessibility value.
                        .accessibilityHidden(true)
                        // GeometryReader inside the bar takes every point it is offered, so the
                        // label has to claim its width first.
                        .layoutPriority(1)
                }
            } else {
                progressBar(fraction: fraction)
            }
        } else if state.chronometer == true, let end = state.countdownEnd {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                HAActivityChronometerText(end: end, start: state.chronometerStart)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                HAActivityTimerProgressBar(
                    start: state.chronometerStart,
                    end: end,
                    tint: barColor,
                    direction: state.resolvedProgressBarDirection
                )
            }
        }
    }

    private func progressBar(fraction: Double) -> some View {
        HAActivityProgressBar(
            fraction: fraction,
            fillColor: barColor,
            trackColor: trackColor,
            height: 6
        )
    }

    private var barColor: Color {
        HAActivityVisualStyle.color(from: state.progressBarColor ?? state.color)
    }

    private var resolvedForeground: Color? {
        HAActivityVisualStyle.foregroundColor(textColor: state.textColor, onBackground: state.backgroundColor)
    }

    private var primaryTextColor: Color {
        resolvedForeground ?? HAActivityVisualStyle.defaultSupplementalForegroundColor
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.8)
    }

    private var trackColor: Color {
        primaryTextColor.opacity(0.12)
    }
}
#endif
