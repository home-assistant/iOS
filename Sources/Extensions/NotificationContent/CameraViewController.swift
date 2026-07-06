import Alamofire
import AVFoundation
import AVKit
import KeychainAccess
import PromiseKit
import SFSafeSymbols
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class CameraViewController: UIViewController, NotificationCategory {
    enum CameraError: LocalizedError {
        case missingEntityId
        case missingAPI

        var errorDescription: String? {
            switch self {
            case .missingEntityId:
                return L10n.Extensions.NotificationContent.Error.noEntityId
            case .missingAPI:
                return HomeAssistantAPI.APIError.notConfigured.localizedDescription
            }
        }
    }

    let entityId: String
    let api: HomeAssistantAPI

    private var isMuted = true

    private lazy var muteButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = 18
        button.setPreferredSymbolConfiguration(.init(pointSize: 15, weight: .semibold), forImageIn: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        return button
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    #if DEBUG
    private lazy var streamTypeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    #endif

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        guard let entityId = notification.request.content.userInfo["entity_id"] as? String,
              entityId.starts(with: "camera.") else {
            throw CameraError.missingEntityId
        }

        self.entityId = entityId
        self.api = api
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        activeViewController?.pause()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        loadingIndicator.startAnimating()

        view.addSubview(muteButton)
        muteButton.isHidden = true
        NSLayoutConstraint.activate([
            muteButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            muteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            muteButton.widthAnchor.constraint(equalToConstant: 36),
            muteButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        #if DEBUG
        view.addSubview(streamTypeLabel)
        NSLayoutConstraint.activate([
            streamTypeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            streamTypeLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            streamTypeLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
        #endif
    }

    var activeViewController: (UIViewController & CameraStreamHandler)? {
        willSet {
            activeViewController?.willMove(toParent: nil)
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let viewController = activeViewController {
                view.addSubview(viewController.view)
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])

                viewController.didMove(toParent: self)

                view.bringSubviewToFront(loadingIndicator)
                view.bringSubviewToFront(muteButton)
                #if DEBUG
                view.bringSubviewToFront(streamTypeLabel)
                #endif
                updateOverlays()
            }
        }
    }

    func start() -> Promise<Void> {
        firstly {
            api.StreamCamera(entityId: entityId)
        }.recover { [entityId] error -> Promise<StreamCameraResponse> in
            Current.Log.info("falling back due to no streaming info for \(entityId) due to \(error)")
            return .value(StreamCameraResponse(fallbackEntityID: entityId))
        }.then { [api] result -> Promise<(StreamCameraResponse, URL)> in
            Promise { seal in
                Task {
                    if let baseURL = await api.server.activeURL() {
                        seal.fulfill((result, baseURL))
                    } else {
                        seal.reject(ServerConnectionError.noActiveURL(api.server.info.name))
                    }
                }
            }
        }.then { [weak self, api, entityId] resultAndBaseURL -> Promise<Void> in
            let (result, baseURL) = resultAndBaseURL
            var controllers = Self.possibleControllers
                .compactMap { controllerClass -> () -> Promise<UIViewController & CameraStreamHandler> in
                    {
                        do {
                            return try .value(controllerClass.init(api: api, response: result, baseURL: baseURL))
                        } catch {
                            return Promise(error: error)
                        }
                    }
                }

            // Prefer WebRTC; it rejects when unsupported so the chain falls through to HLS then MJPEG.
            if #available(iOS 16.0, *) {
                controllers.insert({ () -> Promise<UIViewController & CameraStreamHandler> in
                    .value(CameraStreamWebRTCViewController(api: api, cameraEntityId: entityId))
                }, at: 0)
            }

            return self?.viewController(from: controllers).asVoid() ?? .value(())
        }
    }

    // No system play/pause button: the stream auto-plays once it starts. The only control is the
    // mute/unmute button overlaid in the top-trailing corner.
    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        .none
    }

    // We draw our own centered loader, so suppress the system one.
    var hidesSystemLoadingIndicator: Bool { true }

    var mediaPlayPauseButtonFrame: CGRect? { nil }

    func mediaPlay() {
        activeViewController?.play()
    }

    func mediaPause() {
        activeViewController?.pause()
    }

    private func updateOverlays() {
        guard let active = activeViewController else {
            muteButton.isHidden = true
            return
        }
        active.setMuted(isMuted)
        muteButton.isHidden = !active.hasAudio
        updateMuteIcon()

        #if DEBUG
        streamTypeLabel.text = " \(debugStreamName(for: active)) "
        #endif
    }

    private func updateMuteIcon() {
        muteButton.setImage(UIImage(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave3), for: .normal)
        // Label reflects the action the button performs, so VoiceOver conveys both purpose and state.
        muteButton.accessibilityLabel = isMuted
            ? L10n.Extensions.NotificationContent.Camera.unmute
            : L10n.Extensions.NotificationContent.Camera.mute
    }

    private func setLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    @objc private func toggleMute() {
        isMuted.toggle()
        activeViewController?.setMuted(isMuted)
        updateMuteIcon()
    }

    #if DEBUG
    private func debugStreamName(for controller: UIViewController & CameraStreamHandler) -> String {
        if #available(iOS 16.0, *), controller is CameraStreamWebRTCViewController {
            return "WebRTC"
        }
        if controller is CameraStreamHLSViewController {
            return "AVPlayer (HLS)"
        }
        if controller is CameraStreamMJPEGViewController {
            return "MJPEG"
        }
        return String(describing: type(of: controller))
    }
    #endif

    enum CameraViewControllerError: LocalizedError {
        case noControllers
        case accumulated([Error])

        var errorDescription: String? {
            switch self {
            case .noControllers:
                return nil
            case let .accumulated(errors):
                return errors.map { error in
                    // $0. syntax crashes the swift compiler, at least in xcode 12.4
                    error.localizedDescription
                }.joined(separator: "\n\n")
            }
        }
    }

    private static var possibleControllers: [(UIViewController & CameraStreamHandler).Type] { [
        CameraStreamHLSViewController.self,
        CameraStreamMJPEGViewController.self,
    ] }

    private func viewController(
        from controllerPromises: [() -> Promise<UIViewController & CameraStreamHandler>]
    ) -> Promise<UIViewController & CameraStreamHandler> {
        var accumulatedErrors = [Error]()
        var promise: Promise<UIViewController & CameraStreamHandler> = .init(
            error: CameraViewControllerError.noControllers
        )

        for nextPromise in controllerPromises {
            promise = promise.recover { [extensionContext] error -> Promise<UIViewController & CameraStreamHandler> in
                // always tell the extension context the previous one failed, aka go back to showing pause
                extensionContext?.mediaPlayingPaused()
                // accumulate the error
                if case CameraViewControllerError.noControllers = error {
                    // except the empty one that we started with to make this code nicer
                } else {
                    accumulatedErrors.append(error)
                }

                return firstly {
                    // now try this latest one
                    nextPromise()
                }.get { [weak self, extensionContext] controller in
                    // configure it -- this isn't part of the one-level-up chain because it would run for each one
                    var lastState: CameraStreamHandlerState?
                    controller.didUpdateState = { [weak self] state in
                        guard lastState != state else {
                            return
                        }

                        switch state {
                        case .playing:
                            extensionContext?.mediaPlayingStarted()
                            self?.setLoading(false)
                        case .paused:
                            extensionContext?.mediaPlayingPaused()
                            self?.setLoading(true)
                        }

                        lastState = state
                    }

                    // add it to hirearchy and constrain
                    self?.activeViewController = controller
                }.then { value in
                    // make sure we wait until the controller figures out if it started or failed
                    value.promise.map { value }
                }
            }
        }

        return promise.recover { nextError -> Promise<UIViewController & CameraStreamHandler> in
            throw CameraViewControllerError.accumulated(accumulatedErrors + [nextError])
        }
    }
}
