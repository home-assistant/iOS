import Shared
import SwiftUI
import UIKit
import WebRTC

class WebRTCVideoPlayerViewController: UIViewController {
    private let viewModel: WebRTCViewPlayerViewModel
    private var remoteVideoView: RTCMTLVideoView!

    var onVideoStarted: (() -> Void)?
    var onVideoSizeChanged: ((CGSize) -> Void)?

    init(viewModel: WebRTCViewPlayerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
        // The peer connection is created after the client config is fetched, so the renderer is
        // registered up front and attached by the view model once the connection exists.
        viewModel.attach(renderer: remoteVideoView)
        viewModel.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stop()
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
}

extension WebRTCVideoPlayerViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        // Hide loader when the first frame is rendered
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.handleVideoRendered()
            self?.onVideoStarted?()
            self?.onVideoSizeChanged?(size)
        }
    }
}
