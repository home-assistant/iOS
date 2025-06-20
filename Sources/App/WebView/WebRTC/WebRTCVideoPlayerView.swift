import SwiftUI
import Shared
import WebRTC

struct WebRTCVideoPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebRTCVideoPlayerViewControllerWrapper(scale: $scale)
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { value in
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

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController()
        vc.view.transform = CGAffineTransform(scaleX: scale, y: scale)
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        uiViewController.view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
