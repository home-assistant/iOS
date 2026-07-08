import Foundation
import PromiseKit
import Shared
import UIKit
import WebRTC

/// Hosts the in-app WebRTC player as a `CameraStreamHandler` so live camera notifications prefer
/// WebRTC, falling back to HLS/MJPEG. Resolves `promise` on first frame; rejects on failure/timeout.
final class CameraStreamWebRTCViewController: UIViewController, CameraStreamHandler {
    enum WebRTCError: LocalizedError {
        /// WebRTC needs the entity id, which isn't in `StreamCameraResponse`; use `init(api:cameraEntityId:)`.
        case requiresEntityID
        case unavailable

        var errorDescription: String? {
            L10n.Extensions.NotificationContent.Error.Request.webrtcUnavailable
        }
    }

    private static let connectionTimeout: TimeInterval = 8

    let promise: Promise<Void>
    var didUpdateState: (CameraStreamHandlerState) -> Void = { _ in }

    private let api: HomeAssistantAPI
    private let cameraEntityId: String
    private let viewModel: WebRTCViewPlayerViewModel
    private let seal: Resolver<Void>
    private var playerViewController: WebRTCVideoPlayerViewController?
    private var timeoutWorkItem: DispatchWorkItem?
    private var hasResolved = false

    // The extension auto-sizes to content; without an aspect ratio the video collapses to zero height
    // and the Metal view never gets a drawable (no frames). HLS/MJPEG use the same 16:9 trick.
    private var aspectRatioConstraint: NSLayoutConstraint? {
        willSet { aspectRatioConstraint?.isActive = false }
        didSet { aspectRatioConstraint?.isActive = true }
    }

    private var lastSize: CGSize? {
        didSet {
            guard oldValue != lastSize, let size = lastSize, let target = playerViewController?.view else {
                return
            }
            aspectRatioConstraint = NSLayoutConstraint.aspectRatioConstraint(on: target, size: size)
        }
    }

    required convenience init(api: HomeAssistantAPI, response: StreamCameraResponse) throws {
        throw WebRTCError.requiresEntityID
    }

    init(api: HomeAssistantAPI, cameraEntityId: String) {
        self.api = api
        self.cameraEntityId = cameraEntityId
        self.viewModel = WebRTCViewPlayerViewModel(server: api.server, cameraEntityId: cameraEntityId)
        (self.promise, self.seal) = Promise<Void>.pending()
        super.init(nibName: nil, bundle: nil)

        viewModel.onFailure = { [weak self] in
            self?.handleFailure()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timeoutWorkItem?.cancel()
        viewModel.webRTCClient?.closeConnection()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        attachPlayer()
        startTimeout()
    }

    func play() {
        // Only (re)start if we're not already connected/connecting. Don't report `.playing` here —
        // the stream is loading until the first frame arrives (handleVideoStarted reports playing).
        guard playerViewController == nil else { return }
        didUpdateState(.paused)
        attachPlayer()
        startTimeout()
    }

    func pause() {
        detachPlayer()
        didUpdateState(.paused)
    }

    var hasAudio: Bool { true }

    var isMuted: Bool { viewModel.webRTCClient?.isAudioMuted() ?? true }

    func setMuted(_ muted: Bool) {
        guard let client = viewModel.webRTCClient else { return }
        muted ? client.muteAudio() : client.unmuteAudio()
    }

    private func attachPlayer() {
        let controller = WebRTCVideoPlayerViewController(viewModel: viewModel)
        controller.onVideoStarted = { [weak self] in
            self?.handleVideoStarted()
        }
        controller.onVideoSizeChanged = { [weak self] size in
            guard size.width > 0, size.height > 0 else { return }
            self?.lastSize = size
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        controller.didMove(toParent: self)
        playerViewController = controller
        lastSize = CGSize(width: 16, height: 9)
    }

    private func detachPlayer() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        viewModel.webRTCClient?.closeConnection()
        playerViewController?.willMove(toParent: nil)
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil
    }

    private func startTimeout() {
        timeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Current.Log.info("WebRTC notification stream timed out, falling back")
            self?.handleFailure()
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectionTimeout, execute: workItem)
    }

    private func handleVideoStarted() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        didUpdateState(.playing)
        guard !hasResolved else { return }
        hasResolved = true
        Current.Log.info("WebRTC notification stream started")
        seal.fulfill(())
    }

    private func handleFailure() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        guard !hasResolved else { return }
        hasResolved = true
        // Tear down the peer connection now rather than waiting for deinit, so we don't keep a
        // failed/timed-out connection alive while the cascade falls back to HLS/MJPEG.
        viewModel.webRTCClient?.closeConnection()
        seal.reject(WebRTCError.unavailable)
    }
}
