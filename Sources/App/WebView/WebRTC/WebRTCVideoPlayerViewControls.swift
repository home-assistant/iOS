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
                    topButtons
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

    @ViewBuilder
    private var topButtons: some View {
        Button(action: toggleMute) {
            Image(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave3)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .padding(DesignSystem.Spaces.oneAndHalf)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view.glassEffect(.clear.interactive(), in: .circle)
                    } else {
                        view
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
        }
        .buttonStyle(.plain)
        ModalCloseButton(tint: .white) {
            close()
        }
        .padding(16)
    }
}

#Preview {
    WebRTCVideoPlayerViewControls(
        close: {},
        isMuted: false,
        toggleMute: {}
    )
}
