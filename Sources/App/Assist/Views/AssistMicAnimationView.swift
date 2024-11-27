import SFSafeSymbols
import Shared
import SwiftUI

struct AssistMicAnimationView: View {
    @State private var isAnimating = false

    private let symbol: SFSymbol = {
        if #available(iOS 18.0, *) {
            return .micCircleFill
        } else {
            return .stopCircle
        }
    }()

    var body: some View {
        content
            .onAppear {
                isAnimating = true
            }
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 18, *) {
            icon
                .foregroundStyle(Color(uiColor: .systemBackground), Color.asset(Asset.Colors.haPrimary))
                .symbolEffect(.breathe.pulse, options: .repeat(.continuous), value: isAnimating)
        } else {
            VStack(spacing: Spaces.one) {
                icon
                    .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
                Text(L10n.Assist.Button.Listening.title)
                    .opacity(0.5)
            }
        }
    }

    private var icon: some View {
        Image(systemSymbol: symbol)
            .font(.system(size: 60))
    }
}

#Preview {
    AssistMicAnimationView()
}
