#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Trailing slot of the compact Dynamic Island: the chronometer, the critical text or the progress
/// percentage, whichever the content state carries.
@available(iOS 17.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    /// Fixed width for the countdown timer text in compact trailing.
    /// 44 pt fits "M:SS" at caption2 size and prevents the Dynamic Island from
    /// squeezing the slot narrower than the text needs.
    private static let compactTrailingTimerWidth: CGFloat = 44
    /// Maximum width for non-timer compact trailing content (criticalText, progress %).
    private static let compactTrailingMaxWidth: CGFloat = 50
    private static let compactTrailingMinimumScaleFactor: CGFloat = 0.7

    var body: some View {
        if state.chronometer == true, let end = state.countdownEnd {
            HAActivityCompactChronometerText(end: end, start: state.chronometerStart)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(Self.compactTrailingMinimumScaleFactor)
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
