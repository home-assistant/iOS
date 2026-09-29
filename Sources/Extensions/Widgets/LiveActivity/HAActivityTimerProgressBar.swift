#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Ticking chronometer text for a Live Activity, mirroring Android's chronometer semantics:
/// counts down while `end` is in the future, and counts up from `end` once it has passed
/// (a `when` at or before now — e.g. `when: 0, when_relative: true` — is a count-up timer).
/// With a `start` anchor (negative relative `when`; the explicit `when_start` if sent, else
/// receipt time), it instead counts up from `start` toward `end` and freezes there — a bounded
/// count-up.
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
    /// Bounded count-up anchor (`chronometerStart`); when set and before `end` it takes precedence.
    let start: Date?
    /// Explicit timer start (`timerStart`). For a countdown the bar spans it → `end` instead of
    /// now → `end`, so updates don't visually reset it; for a bounded count-up it equals `start`,
    /// which already wins. The chronometer text is unaffected.
    let timerStart: Date?
    let end: Date
    let tint: Color
    /// Explicit `progress_bar_direction` override; nil keeps the per-timer default
    /// (countdown drains, bounded count-up fills).
    let direction: HALiveActivityAttributes.ContentState.ProgressBarDirection?

    var body: some View {
        if let interval = Self.interval(
            start: start,
            timerStart: timerStart,
            end: end,
            direction: direction,
            now: .now
        ) {
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
    /// while a countdown drains; `direction` overrides that fill direction. A running countdown
    /// spans `timerStart` → `end` when that start precedes the end, else now → `end`. A
    /// finished countdown and an unbounded count-up have no interval — no bar.
    /// `now` is passed in once so the range can't invalidate between check and use.
    static func interval(
        start: Date?,
        timerStart: Date?,
        end: Date,
        direction: HALiveActivityAttributes.ContentState.ProgressBarDirection?,
        now: Date
    ) -> (range: ClosedRange<Date>, countsDown: Bool)? {
        if let start, start < end {
            return (start ... end, direction == .decreasing)
        }
        guard end > now else { return nil }
        let lower = timerStart.flatMap { $0 < end ? $0 : nil } ?? now
        return (lower ... end, direction != .increasing)
    }
}
#endif
