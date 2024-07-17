import Shared
import SwiftUI

struct ImprovSuccessView: View {
    let action: () -> Void
    var body: some View {
        Spacer()
        VStack(spacing: Spaces.two) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 35))
                    .foregroundStyle(.white, .green)
                    .overlay(
                        Circle()
                            .stroke(.regularMaterial, lineWidth: 5)
                    )
            }
            Text(L10n.Improv.State.success)
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
            Text(L10n.Improv.Button.continue)
                .foregroundStyle(Color(uiColor: .label))
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ImprovSuccessView {}
}
