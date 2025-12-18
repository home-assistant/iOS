import Shared
import SwiftUI

struct WebViewLoadingStateView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .opacity(0.8)
            VStack(spacing: DesignSystem.Spaces.two) {
                HAProgressView(style: .large)
                Text("Loading...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WebViewLoadingStateView()
}
