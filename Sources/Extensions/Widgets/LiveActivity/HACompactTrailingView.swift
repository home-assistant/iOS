#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Trailing slot of the compact Dynamic Island: the critical text, the chronometer or the progress
/// percentage, whichever the content state carries.
///
/// This is the one slot that has to drop something: it is ~50 pt wide and holds a single value.
/// `critical_text` wins it because sending that field is always deliberate, while the chronometer
/// is still read on the Lock Screen and in the expanded island, so nothing is lost overall — and
/// the timer keeps the pill for every activity that does not set `critical_text`.
@available(iOS 17.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    /// Fixed width for the countdown timer text in compact trailing, wide enough for `H:MM:SS`
    /// once the text scales down, and preventing the Dynamic Island from squeezing the slot
    /// narrower than the text needs.
    private static let compactTrailingTimerWidth: CGFloat = 50
    /// Maximum width for non-timer compact trailing content (criticalText, progress %).
    private static let compactTrailingMaxWidth: CGFloat = 50
    private static let compactTrailingMinimumScaleFactor: CGFloat = 0.6

    var body: some View {
        if let critical = state.criticalText {
            Text(critical)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(Self.compactTrailingMinimumScaleFactor)
                .frame(maxWidth: Self.compactTrailingMaxWidth)
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
                .frame(width: Self.compactTrailingTimerWidth)
        } else if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
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
#endif
