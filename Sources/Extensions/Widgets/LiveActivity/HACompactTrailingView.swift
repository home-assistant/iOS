#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Trailing slot of the compact Dynamic Island: the chronometer, the critical text or the progress
/// percentage, whichever the content state carries.
@available(iOS 17.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState
    /// Lays the slot out for a narrow island regardless of the device, for previews and snapshots:
    /// the system value cannot be set from outside.
    var forcesLimitedWidth = false

    @Environment(\.haIsDynamicIslandLimitedInWidth) private var systemLimitedInWidth

    /// Fixed width for the countdown timer text in compact trailing, wide enough for `H:MM:SS`
    /// once the text scales down, and preventing the Dynamic Island from squeezing the slot
    /// narrower than the text needs.
    private static let compactTrailingTimerWidth: CGFloat = 50
    /// Maximum width for non-timer compact trailing content (criticalText, progress %).
    private static let compactTrailingMaxWidth: CGFloat = 50
    private static let compactTrailingMinimumScaleFactor: CGFloat = 0.6
    /// The circle the system gives the slot on a narrow island.
    private static let limitedWidthSlotSize: CGFloat = 28
    /// Diameter of the ring a narrow island shows in place of the text, inside that circle.
    private static let limitedWidthRingSize: CGFloat = 22

    var body: some View {
        if isLimitedInWidth {
            // A narrow island (iPhone Duo, landscape, or one shared with another activity) leaves
            // a 28pt circle, too small for any of the texts, so the timer and the progress become
            // a ring, the timer first as in the full-width slot. Critical text has no graphic
            // form and is left out; the system hides an empty trailing slot.
            if state.chronometer == true, let end = state.countdownEnd {
                if let interval = HAActivityTimerProgressBar.interval(
                    start: state.chronometerStart,
                    end: end,
                    direction: state.resolvedProgressBarDirection
                ) {
                    ProgressView(
                        timerInterval: interval.range,
                        countsDown: interval.countsDown,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .progressViewStyle(.circular)
                    .tint(ringColor)
                    .frame(width: Self.limitedWidthRingSize, height: Self.limitedWidthRingSize)
                } else {
                    // A count-up with no end has nothing to fill a ring with, so it keeps its
                    // elapsed time, scaled down to the circle.
                    HAActivityChronometerText(end: end, start: state.chronometerStart)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(Self.compactTrailingMinimumScaleFactor)
                        .frame(width: Self.limitedWidthSlotSize)
                }
            } else if let fraction = state.progressBarFillFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.circular)
                    .tint(ringColor)
                    .frame(width: Self.limitedWidthRingSize, height: Self.limitedWidthRingSize)
            }
        } else if state.chronometer == true, let end = state.countdownEnd {
            // A timer past an hour needs three fields, which don't fit at full size. Scaling the
            // text keeps the whole value readable; the seconds cannot be dropped instead, because
            // every format style that hides them either spells the units out or cannot be archived
            // for the out-of-process Live Activity renderer.
            HAActivityChronometerText(end: end, start: state.chronometerStart)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(Self.compactTrailingMinimumScaleFactor)
                .multilineTextAlignment(.trailing)
                .frame(width: Self.compactTrailingTimerWidth)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(Self.compactTrailingMinimumScaleFactor)
                .frame(maxWidth: Self.compactTrailingMaxWidth)
        } else if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var isLimitedInWidth: Bool {
        forcesLimitedWidth || systemLimitedInWidth
    }

    /// Same tint as the expanded progress bar: `progress_bar_color`, else the icon color.
    private var ringColor: Color {
        HAActivityVisualStyle.color(from: state.progressBarColor ?? state.color)
    }
}

@available(iOS 17.2, *)
#Preview {
    VStack(alignment: .trailing, spacing: DesignSystem.Spaces.one) {
        HACompactTrailingView(
            state: .init(
                message: "Pasta",
                chronometer: true,
                countdownEnd: Current.date().addingTimeInterval(12013),
                icon: "timer",
                color: "#FF9800"
            )
        )
        HACompactTrailingView(
            state: .init(
                message: "Pasta",
                chronometer: true,
                countdownEnd: Current.date().addingTimeInterval(1500),
                icon: "timer",
                color: "#FF9800"
            )
        )
        HACompactTrailingView(
            state: .init(
                message: "Charging paused",
                criticalText: "03:20:13",
                icon: "battery-alert",
                color: "#F44336"
            )
        )
        HACompactTrailingView(
            state: .init(
                message: "Washing cycle",
                progress: 40,
                progressMax: 100,
                icon: "washing-machine",
                color: "#03A9F4"
            )
        )
    }
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}

@available(iOS 17.2, *)
#Preview("Limited width") {
    HStack(spacing: DesignSystem.Spaces.one) {
        HACompactTrailingView(
            state: .init(
                message: "Pasta",
                chronometer: true,
                countdownEnd: Current.date().addingTimeInterval(1500),
                icon: "timer",
                color: "#FF9800"
            ),
            forcesLimitedWidth: true
        )
        HACompactTrailingView(
            state: .init(
                message: "Workout",
                chronometer: true,
                countdownEnd: Current.date().addingTimeInterval(-754),
                icon: "run",
                color: "#4CAF50"
            ),
            forcesLimitedWidth: true
        )
        HACompactTrailingView(
            state: .init(
                message: "Washing cycle",
                progress: 40,
                progressMax: 100,
                icon: "washing-machine",
                color: "#03A9F4"
            ),
            forcesLimitedWidth: true
        )
    }
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif
