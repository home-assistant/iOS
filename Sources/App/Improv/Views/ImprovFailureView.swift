import Shared
import SwiftUI

struct ImprovFailureView: View {
    let message: String
    let action: () -> Void
    var body: some View {
        Spacer()
        VStack(spacing: Spaces.two) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white, .red)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        Spacer()
        Button {
            action()
        } label: {
            Text(L10n.Improv.Button.continue)
                .padding()
                .foregroundColor(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ImprovFailureView(message: "Something went wrong", action: {})
}
