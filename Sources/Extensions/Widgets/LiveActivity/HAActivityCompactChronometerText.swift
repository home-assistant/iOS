#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Ticking chronometer text for the Dynamic Island compact trailing slot, which is too narrow for
/// `H:MM:SS`. On iOS 18+ the value is capped at two fields (`H:MM` above an hour, `M:SS` below);
/// earlier versions keep the system three-field timer.
///
/// Only the system format styles are used here. A Live Activity view is archived and rendered by
/// the system out of process, and a custom `DiscreteFormatStyle` cannot be archived — the slot then
/// renders as an empty placeholder instead of the timer.
@available(iOS 17.2, *)
struct HAActivityCompactChronometerText: View {
    let end: Date
    let start: Date?

    /// Hours and minutes, or minutes and seconds — never all three.
    private static let maxFieldCount = 2

    var body: some View {
        if #available(iOS 18.0, *) {
            // Capture now once: a second Date.now could advance past `end` between the
            // comparison and the range construction, re-introducing the range trap.
            let now = Date.now
            if let start, start < end {
                // Bounded count-up: elapsed since `start`, pausing at `end` (0:00 → total duration).
                Text(.currentDate, format: .timer(countingUpIn: start ..< end, maxFieldCount: Self.maxFieldCount))
                    .contentTransition(.numericText())
            } else if end > now {
                Text(.currentDate, format: .timer(countingDownIn: now ..< end, maxFieldCount: Self.maxFieldCount))
                    .contentTransition(.numericText(countsDown: true))
            } else {
                // Unbounded count-up since `end`. `Timer` needs a bounded range, so the stopwatch
                // style covers this one, dropped to whole seconds to match the other two.
                Text(
                    .currentDate,
                    format: .stopwatch(
                        startingAt: end,
                        maxFieldCount: Self.maxFieldCount,
                        maxPrecision: .seconds(1)
                    )
                )
                .contentTransition(.numericText())
            }
        } else {
            HAActivityChronometerText(end: end, start: start)
        }
    }
}

@available(iOS 17.2, *)
#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
        HAActivityCompactChronometerText(end: Current.date().addingTimeInterval(12013), start: nil)
        HAActivityCompactChronometerText(end: Current.date().addingTimeInterval(1500), start: nil)
        HAActivityCompactChronometerText(end: Current.date().addingTimeInterval(-600), start: nil)
        HAActivityCompactChronometerText(
            end: Current.date().addingTimeInterval(600),
            start: Current.date().addingTimeInterval(-8400)
        )
    }
    .font(.footnote.monospacedDigit())
    .foregroundStyle(.white)
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif
