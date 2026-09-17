import Shared
import SwiftUI

/// Covers a standalone more-info sheet while its frontend boots, the way the stand-by view covers
/// the main frontend: the native loader shows and the frontend's own launch screen never does.
struct StandaloneMoreInfoLoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            HAProgressView(style: .large)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    StandaloneMoreInfoLoadingView()
}
