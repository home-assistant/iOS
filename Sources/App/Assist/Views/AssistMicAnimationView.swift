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
                .foregroundStyle(Color(uiColor: .systemBackground), Color.haPrimary)
                .symbolEffect(.breathe.pulse, options: .repeat(.continuous), value: isAnimating)
        } else {
            VStack(spacing: DesignSystem.Spaces.one) {
                icon
                    .foregroundStyle(Color.haPrimary)
                Text(verbatim: L10n.Assist.Button.Listening.title)
                    .opacity(0.5)
                    .padding(.bottom)
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
