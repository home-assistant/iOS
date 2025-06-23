import Shared
import SwiftUI
import UIKit
import WebRTC

class WebRTCVideoPlayerViewController: UIViewController {
    private let viewModel: WebRTCViewPlayerViewModel
    private var remoteVideoView: RTCMTLVideoView!
    private var activityIndicatorHost: UIHostingController<HAProgressView>?

    var onVideoStarted: (() -> Void)?

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
        setupActivityIndicator()
        viewModel.start()
        if let client = viewModel.webRTCClient {
            client.renderRemoteVideo(to: remoteVideoView)
        }
        activityIndicatorHost?.view.isHidden = false
    }

    private func setupVideoView() {
        remoteVideoView = RTCMTLVideoView(frame: view.bounds)
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        remoteVideoView.delegate = self
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

    private func setupActivityIndicator() {
        let progressView = HAProgressView(style: .large)
        let host = UIHostingController(rootView: progressView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        activityIndicatorHost = host
    }
}

extension WebRTCVideoPlayerViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        // Hide loader when the first frame is rendered
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicatorHost?.view.isHidden = true
            self?.onVideoStarted?()
        }
    }
}
