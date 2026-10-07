#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Trailing slot of the expanded Dynamic Island: the chronometer, the critical text or the progress
/// percentage, whichever the content state carries, in the order the compact trailing slot uses.
@available(iOS 17.2, *)
struct HAExpandedTrailingView: View {
    let state: HALiveActivityAttributes.ContentState
    private let minimumScaleFactor: CGFloat = 0.7

    /// `Text(timerInterval:)` reserves room for the widest value it could tick through, which is far
    /// more than the digits need and squeezes the title column. Capping the width hands that space
    /// back to the text; `H:MM:SS` scales down into it rather than clipping. `fixedSize()` would
    /// also collapse the reserved width, but it crashes the Live Activity renderer.
    private static let chronometerMaxWidth: CGFloat = 76

    var body: some View {
        if state.chronometer == true, let end = state.countdownEnd {
            HAActivityChronometerText(end: end, start: state.chronometerStart)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
                .frame(maxWidth: Self.chronometerMaxWidth, alignment: .trailing)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        } else if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        }
    }
}

@available(iOS 17.2, *)
#Preview {
    HAExpandedTrailingView(
        state: .init(message: "Charging paused", criticalText: "20%", icon: "battery-alert", color: "#F44336")
    )
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif
