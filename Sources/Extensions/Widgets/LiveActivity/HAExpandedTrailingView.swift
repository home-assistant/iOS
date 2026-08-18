#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HAExpandedTrailingView: View {
    let state: HALiveActivityAttributes.ContentState
    private let minimumScaleFactor: CGFloat = 0.7

    var body: some View {
        if let critical = state.criticalText {
            Text(critical)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        } else if let fraction = state.progressFraction {
            Text(HAActivityVisualStyle.percentString(for: fraction))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
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
