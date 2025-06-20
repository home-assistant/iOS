import Shared
import SwiftUI
import WebRTC

struct WebRTCVideoPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    private let server: Server
    private let cameraEntityId: String

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebRTCVideoPlayerViewControllerWrapper(scale: $scale, server: server, cameraEntityId: cameraEntityId)
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .gesture(
                    TapGesture(count: 2).onEnded {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                        }
                    }
                )
            CloseButton(tint: .white, size: .medium, alternativeAction: {
                dismiss()

            })
            .padding()
        }
        .background(.black)
    }
}

struct WebRTCVideoPlayerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var scale: CGFloat
    private let server: Server
    private let cameraEntityId: String

    init(scale: Binding<CGFloat>, server: Server, cameraEntityId: String) {
        self._scale = scale
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(server: server, cameraEntityId: cameraEntityId)
        vc.view.transform = CGAffineTransform(scaleX: scale, y: scale)
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        uiViewController.view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
