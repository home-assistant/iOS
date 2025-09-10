import Shared
import SwiftUI

struct WebRTCVideoPlayerViewControls: View {
    let close: () -> Void

    // TODO: Include more player controls
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    ModalCloseButton(tint: .white) {
                        close()
                    }
                    .padding(16)
                }
                Spacer()
                Text(L10n.WebRTCPlayer.Experimental.disclaimer)
                    .font(DesignSystem.Font.footnote.weight(.light))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    .black, .clear, .black,
                ], startPoint: .top, endPoint: .bottom
            )
            .opacity(0.5)
        )
    }
}

#Preview {
    WebRTCVideoPlayerViewControls(
        close: {}
    )
}
