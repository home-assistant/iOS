import Shared
import UIKit
import WebRTC

class WebRTCVideoPlayerViewController: UIViewController {
    private let viewModel: WebRTCViewPlayerViewModel
    private var remoteVideoView: RTCMTLVideoView!

    init(server: Server, cameraEntityId: String) {
        self.viewModel = .init(server: server, cameraEntityId: cameraEntityId)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
        viewModel.start()
        if let client = viewModel.webRTCClient {
            client.renderRemoteVideo(to: remoteVideoView)
        }
    }

    private func setupVideoView() {
        remoteVideoView = RTCMTLVideoView(frame: view.bounds)
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(remoteVideoView)
        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        remoteVideoView.videoContentMode = .scaleAspectFit
        remoteVideoView.backgroundColor = .black
    }
}
