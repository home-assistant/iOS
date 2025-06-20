import UIKit
import WebRTC

class WebRTCVideoPlayerViewController: UIViewController {
    private let viewModel = WebRTCViewPlayerViewModel()
    private var remoteVideoView: RTCMTLVideoView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
        viewModel.webRTCClient = nil // Ensure clean state
        viewModel.start()
        if let client = viewModel.webRTCClient {
            client.renderRemoteVideo(to: remoteVideoView)
        }
    }

    private func setupVideoView() {
        remoteVideoView = RTCMTLVideoView(frame: self.view.bounds)
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(remoteVideoView)
        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        remoteVideoView.videoContentMode = .scaleAspectFit
        remoteVideoView.backgroundColor = .black
    }
}

