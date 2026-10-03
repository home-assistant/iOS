#if os(macOS)
import Shared
import SwiftUI

struct MacConfirmationHUDView: View {
    let icon: MaterialDesignIcons
    let text: String

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(uiImage: icon.image(ofSize: .init(width: 64, height: 64), color: .label))
                .renderingMode(.template)
                .foregroundStyle(.primary)
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spaces.three)
        .frame(minWidth: 160)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.three))
    }
}

#Preview {
    MacConfirmationHUDView(icon: .checkIcon, text: "Done")
        .padding()
}
#endif
