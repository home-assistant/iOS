import Shared
import SwiftUI

struct HomeAssistantPullToRefreshView: View {
    let progress: CGFloat
    let isRefreshing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

            if isRefreshing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.haPrimary)
            } else {
                Circle()
                    .trim(from: 0, to: max(0.12, progress))
                    .stroke(
                        Color.haPrimary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(10)
            }
        }
        .frame(width: 42, height: 42)
        .scaleEffect(isRefreshing ? 1 : 0.8 + (0.2 * progress))
        .opacity(isRefreshing ? 1 : progress)
        .accessibilityHidden(true)
    }
}

#Preview("Pulling") {
    HomeAssistantPullToRefreshView(progress: 0.65, isRefreshing: false)
        .padding()
}

#Preview("Refreshing") {
    HomeAssistantPullToRefreshView(progress: 1, isRefreshing: true)
        .padding()
}
