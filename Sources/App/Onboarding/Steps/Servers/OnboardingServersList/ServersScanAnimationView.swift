import SFSafeSymbols
import Shared
import SwiftUI

struct ServersScanAnimationView: View {
    @State private var isAnimating = false
    var body: some View {
        VStack(spacing: Spaces.two) {
            if #available(iOS 18, *) {
                mainIcon
                    .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
            } else {
                mainIcon
            }
            Text(L10n.Onboarding.Servers.Search.message)
                .font(.footnote)
                .foregroundStyle(.gray)
        }
    }

    private var mainIcon: some View {
        Image(systemSymbol: .textMagnifyingglass)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .foregroundColor(.gray)
            .onAppear {
                isAnimating = true
            }
            .onDisappear {
                isAnimating = false
            }
    }
}

#Preview {
    ServersScanAnimationView()
}
