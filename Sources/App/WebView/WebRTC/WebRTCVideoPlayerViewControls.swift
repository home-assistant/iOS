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
                    CloseButton(tint: .white, size: .large) {
                        close()
                    }
                    .padding(16)
                }
                Spacer()
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
