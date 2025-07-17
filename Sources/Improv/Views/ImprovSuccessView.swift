import Shared
import SwiftUI

struct ImprovSuccessView: View {
    let action: () -> Void
    var body: some View {
        Spacer()
        VStack(spacing: DesignSystem.Spaces.two) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.white, Color.haPrimary)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 35))
                    .foregroundStyle(.white, .green)
                    .overlay(
                        Circle()
                            .stroke(.regularMaterial, lineWidth: 5)
                    )
            }
            Text(verbatim: L10n.Improv.State.success)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        Spacer()
        nextButton
    }

    @ViewBuilder
    private var nextButton: some View {
        Button {
            action()
        } label: {
            Text(verbatim: L10n.Improv.Button.continue)
        }
        .buttonStyle(.primaryButton)
        .padding()
    }
}

#Preview {
    ImprovSuccessView {}
}
