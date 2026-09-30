import Alamofire
import AVFoundation
import AVKit
import KeychainAccess
import PromiseKit
import SFSafeSymbols
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UserNotifications
import UserNotificationsUI

class CameraViewController: PlatformViewController, NotificationCategory {
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

    /// A stream controller: the view controller drawing one kind of stream and the handler that drives it.
    typealias StreamController = CameraStreamHandler & PlatformViewController

    let entityId: String
    let api: HomeAssistantAPI

    private var isMuted = true

    #if os(macOS)
    private lazy var muteButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        button.layer?.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(toggleMute)
        return button
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        // Drawn as it would be on a dark background so it shows over the stream, like the white one on iOS.
        indicator.appearance = NSAppearance(named: .darkAqua)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    #if DEBUG
    private lazy var streamTypeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.drawsBackground = true
        label.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.layer?.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    #endif
    #else
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

    #if os(macOS)
    override func loadView() {
        view = NSView()
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        #if os(macOS)
        NSLayoutConstraint.activate([
            loadingIndicator.widthAnchor.constraint(equalToConstant: 32),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 32),
        ])
        #endif
        setLoading(true)

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

    var activeViewController: StreamController? {
        willSet {
            #if !os(macOS)
            activeViewController?.willMove(toParent: nil)
            #endif
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let viewController = activeViewController {
                #if os(macOS)
                // Inserted beneath the overlays, which keeps them in front without re-adding them.
                view.addSubview(viewController.view, positioned: .below, relativeTo: nil)
                #else
                view.addSubview(viewController.view)
                #endif
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])

                #if !os(macOS)
                viewController.didMove(toParent: self)

                view.bringSubviewToFront(loadingIndicator)
                view.bringSubviewToFront(muteButton)
                #if DEBUG
                view.bringSubviewToFront(streamTypeLabel)
                #endif
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
                .compactMap { controllerClass -> () -> Promise<StreamController> in
                    {
                        do {
                            return try .value(controllerClass.init(api: api, response: result, baseURL: baseURL))
                        } catch {
                            return Promise(error: error)
                        }
                    }
                }

            // Prefer WebRTC; it rejects when unsupported so the chain falls through to HLS then MJPEG.
            controllers.insert({ () -> Promise<StreamController> in
                .value(CameraStreamWebRTCViewController(api: api, cameraEntityId: entityId))
            }, at: 0)

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
        #if os(macOS)
        streamTypeLabel.stringValue = " \(debugStreamName(for: active)) "
        #else
        streamTypeLabel.text = " \(debugStreamName(for: active)) "
        #endif
        #endif
    }

    private func updateMuteIcon() {
        let image = UIImage(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave3)
        // Label reflects the action the button performs, so VoiceOver conveys both purpose and state.
        let accessibilityLabel = isMuted
            ? L10n.Extensions.NotificationContent.Camera.unmute
            : L10n.Extensions.NotificationContent.Camera.mute
        #if os(macOS)
        muteButton.image = image
        muteButton.setAccessibilityLabel(accessibilityLabel)
        #else
        muteButton.setImage(image, for: .normal)
        muteButton.accessibilityLabel = accessibilityLabel
        #endif
    }

    private func setLoading(_ loading: Bool) {
        #if os(macOS)
        if loading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
        #else
        if loading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        #endif
    }

    @objc private func toggleMute() {
        isMuted.toggle()
        activeViewController?.setMuted(isMuted)
        updateMuteIcon()
    }

    #if DEBUG
    private func debugStreamName(for controller: StreamController) -> String {
        if controller is CameraStreamWebRTCViewController {
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

    private static var possibleControllers: [StreamController.Type] { [
        CameraStreamHLSViewController.self,
        CameraStreamMJPEGViewController.self,
    ] }

    private func viewController(
        from controllerPromises: [() -> Promise<StreamController>]
    ) -> Promise<StreamController> {
        var accumulatedErrors = [Error]()
        var promise: Promise<StreamController> = .init(
            error: CameraViewControllerError.noControllers
        )

        for nextPromise in controllerPromises {
            promise = promise
                .recover { [weak self, extensionContext] error -> Promise<StreamController> in
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
                    }.get { [extensionContext] controller in
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

        return promise.recover { nextError -> Promise<StreamController> in
            throw CameraViewControllerError.accumulated(accumulatedErrors + [nextError])
        }
    }
}
