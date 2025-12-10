import SFSafeSymbols
import Shared
import SwiftUI

struct WebRTCVideoPlayerViewControls: View {
    let close: () -> Void
    let isMuted: Bool
    let toggleMute: () -> Void

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
                HStack {
                    Button(action: toggleMute) {
                        Image(systemSymbol: isMuted ? .speakerSlashFill : .speakerWaveFill)
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
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
        close: {},
        isMuted: false,
        toggleMute: {}
    )
}
