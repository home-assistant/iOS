#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Ticking chronometer text for a Live Activity, mirroring Android's chronometer semantics:
/// counts down while `end` is in the future, and counts up from `end` once it has passed
/// (a `when` at or before now — e.g. `when: 0, when_relative: true` — is a count-up timer).
/// With a `start` anchor (negative relative `when`), it instead counts up from `start`
/// toward `end` and freezes there — a bounded count-up.
///
/// The count-up branches are also a safety requirement: `Date.now ... end` traps when `end`
/// is already past (ClosedRange requires lowerBound <= upperBound), which would crash the
/// widget render for any chronometer whose end date has passed.
@available(iOS 17.2, *)
struct HAActivityChronometerText: View {
    let end: Date
    let start: Date?

    var body: some View {
        // Capture now once: a second Date.now could advance past `end` between the
        // comparison and the range construction, re-introducing the range trap.
        let now = Date.now
        if let start, start < end {
            // Bounded count-up: elapsed since `start`, pausing at `end` (0:00 → total duration).
            Text(timerInterval: start ... end, countsDown: false)
                .contentTransition(.numericText())
        } else if end > now {
            Text(timerInterval: now ... end, countsDown: true)
                .contentTransition(.numericText(countsDown: true))
        } else {
            Text(end, style: .timer)
                .contentTransition(.numericText())
        }
    }
}

@available(iOS 17.2, *)
struct HAActivityTimerProgressBar: View {
    let start: Date?
    let end: Date
    let tint: Color
    /// Explicit `progress_bar_direction` override; nil keeps the per-timer default
    /// (countdown drains, bounded count-up fills).
    let direction: HALiveActivityAttributes.ContentState.ProgressBarDirection?

    var body: some View {
        if let interval {
            ProgressView(
                timerInterval: interval.range,
                countsDown: interval.countsDown,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .tint(tint)
            .scaleEffect(y: 2)
            .clipShape(.capsule)
        }
    }

    /// By default a bounded count-up fills from `start` to `end` (and stays full once reached)
    /// while a countdown drains; `direction` overrides that fill direction. A countdown only
    /// renders while still running, and an unbounded count-up has no interval — no bar.
    /// `now` is captured once so the range can't invalidate between check and use.
    private var interval: (range: ClosedRange<Date>, countsDown: Bool)? {
        if let start, start < end {
            return (start ... end, direction == .decreasing)
        }
        let now = Date.now
        if end > now {
            return (now ... end, direction != .increasing)
        }
        return nil
    }
}
#endif
