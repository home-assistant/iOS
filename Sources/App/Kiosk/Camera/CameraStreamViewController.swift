import AVKit
import Shared
import SwiftUI
import UIKit
import WebKit

// MARK: - Camera Stream View Controller

/// Full-screen camera view with auto-dismiss capability
@MainActor
public final class CameraStreamViewController: UIViewController {
    // MARK: - Properties

    private let stream: CameraStream
    private let autoDismissInterval: TimeInterval?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var webView: WKWebView?
    private var autoDismissTimer: Timer?
    private var countdownLabel: UILabel?
    private var remainingSeconds: Int = 0

    public var onDismiss: (() -> Void)?

    // MARK: - Initialization

    public init(stream: CameraStream, autoDismiss: TimeInterval? = nil) {
        self.stream = stream
        self.autoDismissInterval = autoDismiss ?? stream.autoDismissSeconds
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupStream()
        setupAutoDismiss()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        webView?.frame = view.bounds
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }

    override public var prefersStatusBarHidden: Bool {
        true
    }

    override public var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Header overlay
        let headerView = createHeaderView()
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
        ])

        // Action buttons (for doorbell)
        if stream.type == .doorbell {
            let actionsView = createActionsView()
            view.addSubview(actionsView)
            actionsView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                actionsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                actionsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
        }

        // Tap to dismiss gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }

    private func createHeaderView() -> UIView {
        let container = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center

        // Camera icon
        let iconView = UIImageView(image: UIImage(systemName: stream.type == .doorbell ? "video.doorbell.fill" : "video.fill"))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true

        // Camera name
        let nameLabel = UILabel()
        nameLabel.text = stream.name
        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        // Countdown label
        let countdown = UILabel()
        countdown.textColor = .white.withAlphaComponent(0.7)
        countdown.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        countdownLabel = countdown

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(dismissCamera), for: .touchUpInside)

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(UIView()) // Spacer
        stack.addArrangedSubview(countdown)
        stack.addArrangedSubview(closeButton)

        container.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
        ])

        return container
    }

    private func createActionsView() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center

        // Talk button
        let talkButton = createActionButton(
            icon: "mic.fill",
            title: "Talk",
            color: .systemGreen,
            action: #selector(handleTalk)
        )
        stack.addArrangedSubview(talkButton)

        // Unlock button (if available)
        if stream.unlockEntityId != nil {
            let unlockButton = createActionButton(
                icon: "lock.open.fill",
                title: "Unlock",
                color: .systemBlue,
                action: #selector(handleUnlock)
            )
            stack.addArrangedSubview(unlockButton)
        }

        // Snapshot button
        let snapshotButton = createActionButton(
            icon: "camera.fill",
            title: "Snapshot",
            color: .systemGray,
            action: #selector(handleSnapshot)
        )
        stack.addArrangedSubview(snapshotButton)

        return stack
    }

    private func createActionButton(icon: String, title: String, color: UIColor, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: icon)
        config.title = title
        config.imagePadding = 8
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setupStream() {
        switch stream.streamType {
        case .hls:
            setupHLSPlayer()
        case .mjpeg:
            setupMJPEGWebView()
        }
    }

    private func setupHLSPlayer() {
        guard let url = stream.hlsURL else {
            Current.Log.warning("No HLS URL for stream: \(stream.name)")
            return
        }

        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let layer = playerLayer {
            view.layer.insertSublayer(layer, at: 0)
        }

        player?.play()
        Current.Log.info("Started HLS stream: \(url)")
    }

    private func setupMJPEGWebView() {
        guard let mjpegPath = stream.mjpegPath,
              let server = Current.servers.all.first,
              let api = Current.api(for: server),
              let url = api.server.info.connection.activeURL()?.appendingPathComponent(mjpegPath) else {
            Current.Log.warning("No MJPEG URL for stream: \(stream.name)")
            return
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView?.backgroundColor = .black
        webView?.isOpaque = false
        webView?.scrollView.isScrollEnabled = false

        if let web = webView {
            view.insertSubview(web, at: 0)
        }

        // Create HTML that displays the MJPEG stream centered
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background: black;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    overflow: hidden;
                }
                img {
                    max-width: 100%;
                    max-height: 100vh;
                    object-fit: contain;
                }
            </style>
        </head>
        <body>
            <img src="\(url.absoluteString)" />
        </body>
        </html>
        """

        webView?.loadHTMLString(html, baseURL: nil)
        Current.Log.info("Started MJPEG stream: \(url)")
    }

    private func setupAutoDismiss() {
        guard let interval = autoDismissInterval, interval > 0 else { return }

        remainingSeconds = Int(interval)
        updateCountdown()

        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.remainingSeconds -= 1
            self.updateCountdown()

            if self.remainingSeconds <= 0 {
                self.dismissCamera()
            }
        }
    }

    private func updateCountdown() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        countdownLabel?.text = String(format: "%d:%02d", minutes, seconds)
    }

    private func cleanup() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
    }

    // MARK: - Actions

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Reset auto-dismiss timer on tap
        if let interval = autoDismissInterval, interval > 0 {
            remainingSeconds = Int(interval)
            updateCountdown()
        }
    }

    @objc private func dismissCamera() {
        cleanup()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func handleTalk() {
        Current.Log.info("Talk button pressed for: \(stream.name)")

        Task {
            await startTwoWayAudio()
        }
    }

    private func startTwoWayAudio() async {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA connection for two-way audio")
            await MainActor.run { showFeedback("No connection") }
            return
        }

        // Determine target media player for audio output
        // Convention: media_player with same name as camera (e.g., camera.front_door -> media_player.front_door)
        let targetEntity = stream.unlockEntityId?.replacingOccurrences(of: "lock.", with: "media_player.")
            ?? stream.entityId.replacingOccurrences(of: "camera.", with: "media_player.")

        Current.Log.info("Two-way audio initiated for: \(stream.name)")

        // Fire event so automations can handle the talk request
        _ = try? await api.connection.send(.init(
            type: "fire_event",
            data: [
                "event_type": "haframe_doorbell_answered",
                "event_data": [
                    "camera_entity_id": stream.entityId,
                    "stream_name": stream.name,
                ],
            ]
        )).promise.value

        // Attempt TTS announcement through associated media player
        _ = try? await api.connection.send(.init(
            type: "call_service",
            data: [
                "domain": "tts",
                "service": "speak",
                "target": ["entity_id": targetEntity],
                "service_data": [
                    "message": "Someone is at the door and viewing the camera.",
                ],
            ]
        )).promise.value

        await MainActor.run {
            showFeedback("Talk initiated")
        }
    }

    @objc private func handleUnlock() {
        guard let entityId = stream.unlockEntityId else { return }

        Current.Log.info("Unlock requested: \(entityId)")

        Task {
            guard let server = Current.servers.all.first,
                  let api = Current.api(for: server) else { return }

            let domain = entityId.split(separator: ".").first ?? "lock"
            _ = try? await api.connection.send(.init(
                type: "call_service",
                data: [
                    "domain": String(domain),
                    "service": "unlock",
                    "target": ["entity_id": entityId],
                ]
            )).promise.value

            // Show brief feedback
            await MainActor.run {
                showFeedback("Unlocked")
            }
        }
    }

    @objc private func handleSnapshot() {
        Current.Log.info("Snapshot requested for: \(stream.entityId)")

        Task {
            guard let server = Current.servers.all.first,
                  let api = Current.api(for: server) else { return }

            _ = try? await api.connection.send(.init(
                type: "call_service",
                data: [
                    "domain": "camera",
                    "service": "snapshot",
                    "target": ["entity_id": stream.entityId],
                    "service_data": ["filename": "/config/www/snapshots/\(stream.id)_\(Date().timeIntervalSince1970).jpg"],
                ]
            )).promise.value

            await MainActor.run {
                showFeedback("Snapshot saved")
            }
        }
    }

    private func showFeedback(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true

        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            label.heightAnchor.constraint(equalToConstant: 44),
        ])

        UIView.animate(withDuration: 0.3, delay: 1.5, options: []) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}

// MARK: - Camera Takeover Manager

@MainActor
public final class CameraTakeoverManager {
    public static let shared = CameraTakeoverManager()

    private weak var presentingViewController: UIViewController?
    private var currentStreamController: CameraStreamViewController?

    public var onDismiss: (() -> Void)?

    private init() {}

    /// Show full-screen camera with optional auto-dismiss
    public func showCamera(
        stream: CameraStream,
        from presenter: UIViewController,
        autoDismiss: TimeInterval? = nil
    ) {
        // Dismiss any existing stream
        dismissCamera()

        let controller = CameraStreamViewController(stream: stream, autoDismiss: autoDismiss)
        controller.onDismiss = { [weak self] in
            self?.currentStreamController = nil
            self?.onDismiss?()
        }

        presentingViewController = presenter
        currentStreamController = controller

        presenter.present(controller, animated: true)
        Current.Log.info("Showing full-screen camera: \(stream.name)")
    }

    /// Dismiss current camera view
    public func dismissCamera() {
        currentStreamController?.dismiss(animated: true)
        currentStreamController = nil
    }

    /// Check if camera is currently showing
    public var isShowingCamera: Bool {
        currentStreamController != nil
    }
}
