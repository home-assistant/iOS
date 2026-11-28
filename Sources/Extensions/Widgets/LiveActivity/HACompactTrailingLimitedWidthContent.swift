#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import Shared

/// What the compact trailing slot of a narrow Dynamic Island shows for a content state. The slot
/// keeps the order of the full-width one (timer, critical text, progress), and a ring fills from
/// the same source as the progress bar: the progress when the state carries one, else the timer.
@available(iOS 17.2, *)
enum HACompactTrailingLimitedWidthContent: Equatable {
    case progressRing(fraction: Double)
    case timerRing(range: ClosedRange<Date>, countsDown: Bool)
    case elapsedTime(end: Date, start: Date?)
    case criticalText(String)

    init?(state: HALiveActivityAttributes.ContentState) {
        if state.chronometer == true, let end = state.countdownEnd {
            if let fraction = state.progressBarFillFraction {
                self = .progressRing(fraction: fraction)
            } else if let interval = HAActivityTimerProgressBar.interval(
                start: state.chronometerStart,
                end: end,
                direction: state.resolvedProgressBarDirection
            ) {
                self = .timerRing(range: interval.range, countsDown: interval.countsDown)
            } else {
                self = .elapsedTime(end: end, start: state.chronometerStart)
            }
        } else if let critical = state.criticalText {
            self = .criticalText(critical)
        } else if let fraction = state.progressBarFillFraction {
            self = .progressRing(fraction: fraction)
        } else {
            return nil
        }
    }
}
#endif
