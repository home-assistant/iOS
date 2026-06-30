#if os(iOS) && !targetEnvironment(macCatalyst)
import SwiftUI

@available(iOS 17.2, *)
struct HAActivityTimerProgressBar: View {
    let end: Date
    let tint: Color

    var body: some View {
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
#endif
