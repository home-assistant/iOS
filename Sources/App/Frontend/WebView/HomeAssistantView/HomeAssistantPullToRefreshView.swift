import Shared
import SwiftUI

struct HomeAssistantPullToRefreshView: View {
    private static let logoAnimationID = "pull-to-refresh-logo"

    let progress: CGFloat
    let isRefreshing: Bool
    let logoNamespace: Namespace.ID?

    init(
        progress: CGFloat,
        isRefreshing: Bool,
        logoNamespace: Namespace.ID? = nil
    ) {
        self.progress = progress
        self.isRefreshing = isRefreshing
        self.logoNamespace = logoNamespace
    }

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
        .modify { view in
            if let logoNamespace {
                view.matchedGeometryEffect(
                    id: Self.logoAnimationID,
                    in: logoNamespace,
                    isSource: true
                )
            } else {
                view
            }
        }
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
