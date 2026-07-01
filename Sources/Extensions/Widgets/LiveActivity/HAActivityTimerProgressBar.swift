#if os(iOS) && !targetEnvironment(macCatalyst)
import SwiftUI

/// Ticking chronometer text for a Live Activity, mirroring Android's chronometer semantics:
/// counts down while `end` is in the future, and counts up from `end` once it has passed
/// (a `when` at or before now — e.g. `when: 0, when_relative: true` — is a count-up timer).
///
/// The count-up branch is also a safety requirement: `Date.now ... end` traps when `end` is
/// already past (ClosedRange requires lowerBound <= upperBound), which would crash the widget
/// render for any chronometer whose end date has passed.
@available(iOS 17.2, *)
struct HAActivityChronometerText: View {
    let end: Date

    var body: some View {
        if end > Date.now {
            Text(timerInterval: Date.now ... end, countsDown: true)
                .contentTransition(.numericText(countsDown: true))
        } else {
            Text(end, style: .timer)
                .contentTransition(.numericText())
        }
    }
}

@available(iOS 17.2, *)
struct HAActivityTimerProgressBar: View {
    let end: Date
    let tint: Color

    var body: some View {
        // A count-up chronometer has no bounded interval, and `Date.now ... end` traps for a
        // past `end` — only render the bar while the countdown is still running.
        if end > Date.now {
            ProgressView(
                timerInterval: Date.now ... end,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .tint(tint)
            .scaleEffect(y: 2)
            .clipShape(.capsule)
        }
    }
}
#endif
