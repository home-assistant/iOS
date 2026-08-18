#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Ticking chronometer text for the Dynamic Island compact trailing slot, which is too narrow for
/// `H:MM:SS`. On iOS 18+ the value is capped at two fields (`H:MM` above an hour, `M:SS` below);
/// earlier versions keep the system three-field timer.
@available(iOS 17.2, *)
struct HAActivityCompactChronometerText: View {
    let end: Date
    let start: Date?

    var body: some View {
        if #available(iOS 18.0, *) {
            let now = Date.now
            if let start, start < end {
                Text(
                    .currentDate,
                    format: HACompactChronometerFormatStyle(anchor: start, direction: .countingUp, freezesAt: end)
                )
                .contentTransition(.numericText())
            } else if end > now {
                Text(.currentDate, format: HACompactChronometerFormatStyle(anchor: end, direction: .countingDown))
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Text(.currentDate, format: HACompactChronometerFormatStyle(anchor: end, direction: .countingUp))
                    .contentTransition(.numericText())
            }
        } else {
            HAActivityChronometerText(end: end, start: start)
        }
    }
}
#endif
