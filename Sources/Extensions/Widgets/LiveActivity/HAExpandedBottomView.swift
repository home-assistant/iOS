#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HAExpandedBottomView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            if state.chronometer == true, let end = state.countdownEnd {
                HAActivityChronometerText(end: end, start: state.chronometerStart)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white)
            } else {
                Text(state.message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
            }
            Group {
                if let fraction = state.progressBarFillFraction {
                    HAActivityProgressBar(
                        fraction: fraction,
                        fillColor: barColor,
                        trackColor: .white.opacity(0.16),
                        height: 8
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
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
