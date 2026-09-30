import Shared
import SwiftUI
import WebRTC

#if os(macOS)
class WebRTCVideoPlayerViewController: NSViewController {
    private let viewModel: WebRTCViewPlayerViewModel
    private var remoteVideoView: RTCMTLNSVideoView!
    /// Holds the video view to the stream's proportions. WebRTC's Mac view has no content mode and
    /// stretches each frame over its whole bounds, so fitting the picture is done by sizing the view.
    private var aspectRatioConstraint: NSLayoutConstraint?
    /// Set when the view left its window, so the stream it stopped on the way out is started again
    /// when the window comes back from being minimised or hidden.
    private var isStopped = false

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

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
        // The peer connection is created after the client config is fetched, so the renderer is
        // registered up front and attached by the view model once the connection exists.
        viewModel.attach(renderer: remoteVideoView)
        viewModel.start()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard isStopped else { return }
        isStopped = false
        viewModel.start()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        isStopped = true
        viewModel.stop()
    }

    private func setupVideoView() {
        remoteVideoView = RTCMTLNSVideoView(frame: view.bounds)
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        remoteVideoView.delegate = self
        view.addSubview(remoteVideoView)

        // As large as the container allows in both directions; once the stream's proportions are
        // known only one of the two can hold, which is what letterboxes the picture.
        let fillWidth = remoteVideoView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fillWidth.priority = .defaultHigh
        let fillHeight = remoteVideoView.heightAnchor.constraint(equalTo: view.heightAnchor)
        fillHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            remoteVideoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remoteVideoView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            remoteVideoView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            remoteVideoView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor),
            fillWidth,
            fillHeight,
        ])
    }

    private func fitVideo(ofSize size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        aspectRatioConstraint?.isActive = false
        let constraint = remoteVideoView.widthAnchor.constraint(
            equalTo: remoteVideoView.heightAnchor,
            multiplier: size.width / size.height
        )
        constraint.isActive = true
        aspectRatioConstraint = constraint
    }
}

extension WebRTCVideoPlayerViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        // Hide loader when the first frame is rendered
        DispatchQueue.main.async { [weak self] in
            self?.fitVideo(ofSize: size)
            self?.viewModel.handleVideoRendered()
            self?.onVideoStarted?()
            self?.onVideoSizeChanged?(size)
        }
    }
}
#else
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
#endif
