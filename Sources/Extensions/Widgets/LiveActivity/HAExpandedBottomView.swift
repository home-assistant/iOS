#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Bottom slot of the expanded Dynamic Island: the progress bar, and nothing at all when the
/// content state has no bar to draw.
@available(iOS 17.2, *)
struct HAExpandedBottomView: View {
    let state: HALiveActivityAttributes.ContentState

    private static let barHeight: CGFloat = 8

    var body: some View {
        if let fraction = state.progressBarFillFraction {
            HAActivityProgressBar(
                fraction: fraction,
                fillColor: barColor,
                trackColor: .white.opacity(0.16),
                height: Self.barHeight
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

    /// Progress bar tint: `progress_bar_color`, else the icon color, else HA blue.
    private var barColor: Color {
        HAActivityVisualStyle.color(from: state.progressBarColor ?? state.color)
    }
}

@available(iOS 17.2, *)
#Preview {
    HAExpandedBottomView(
        state: .init(
            message: "Pasta",
            chronometer: true,
            countdownEnd: Current.date().addingTimeInterval(12013),
            icon: "timer",
            color: "#FF9800"
        )
    )
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif
