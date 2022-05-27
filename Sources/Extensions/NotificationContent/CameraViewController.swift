import Alamofire
import AVFoundation
import AVKit
import KeychainAccess
import PromiseKit
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
            }
        }
    }

    func start() -> Promise<Void> {
        firstly {
            api.StreamCamera(entityId: entityId)
        }.recover { [entityId] error -> Promise<StreamCameraResponse> in
            Current.Log.info("falling back due to no streaming info for \(entityId) due to \(error)")
            return .value(StreamCameraResponse(fallbackEntityID: entityId))
        }.then { [weak self, api] result -> Promise<Void> in
            let controllers = Self.possibleControllers
                .compactMap { controllerClass -> () -> Promise<UIViewController & CameraStreamHandler> in
                    {
                        do {
                            return .value(try controllerClass.init(api: api, response: result))
                        } catch {
                            return Promise(error: error)
                        }
                    }
                }

            return self?.viewController(from: controllers).asVoid() ?? .value(())
        }
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        .overlay
    }

    var mediaPlayPauseButtonFrame: CGRect? { nil }

    func mediaPlay() {
        activeViewController?.play()
    }

    func mediaPause() {
        activeViewController?.pause()
    }

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
                    controller.didUpdateState = { state in
                        guard lastState != state else {
                            return
                        }

                        switch state {
                        case .playing:
                            extensionContext?.mediaPlayingStarted()
                        case .paused:
                            extensionContext?.mediaPlayingPaused()
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
