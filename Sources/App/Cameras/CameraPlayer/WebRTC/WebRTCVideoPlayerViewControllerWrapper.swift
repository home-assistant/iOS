import SwiftUI
import WebRTC

struct WebRTCVideoPlayerViewControllerWrapper: UIViewControllerRepresentable {
    private let viewModel: WebRTCViewPlayerViewModel
    @Binding var isVideoPlaying: Bool

    init(viewModel: WebRTCViewPlayerViewModel, isVideoPlaying: Binding<Bool>) {
        self.viewModel = viewModel
        self._isVideoPlaying = isVideoPlaying
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(viewModel: viewModel)
        vc.onVideoStarted = { [weak coordinator = context.coordinator] in
            coordinator?.videoDidStart()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        /* no-op */
    }

    class Coordinator {
        var parent: WebRTCVideoPlayerViewControllerWrapper

        init(parent: WebRTCVideoPlayerViewControllerWrapper) {
            self.parent = parent
        }

        func videoDidStart() {
            parent.isVideoPlaying = true
        }
    }
}
