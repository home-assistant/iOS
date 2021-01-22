//
//  Camera.swift
//  NotificationContentExtension
//
//  Created by Robert Trencheny on 10/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import KeychainAccess
import Shared
import Alamofire
import AVFoundation
import AVKit
import PromiseKit

class CameraViewController: UIViewController, NotificationCategory {
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
                    viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])

                viewController.didMove(toParent: self)
            }
        }
    }

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

    func didReceive(notification: UNNotification, extensionContext: NSExtensionContext?) -> Promise<Void> {
        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            return .init(error: CameraError.missingEntityId)
        }

        return Current.api.then { (api: HomeAssistantAPI) -> Promise<(HomeAssistantAPI, StreamCameraResponse)> in
            return firstly {
                api.StreamCamera(entityId: entityId)
            }.recover { error -> Promise<StreamCameraResponse> in
                Current.Log.info("falling back due to no streaming info for \(entityId) due to \(error)")
                return .value(StreamCameraResponse(fallbackEntityID: entityId))
            }.map {
                (api, $0)
            }
        }.then { [weak self] (api, result) -> Promise<Void> in
            let controllers = Self.possibleControllers
                .compactMap { (controllerClass) -> () -> Promise<UIViewController & CameraStreamHandler> in
                    return {
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
            case .accumulated(let errors):
                return errors.map { $0.localizedDescription }.joined(separator: "\n\n")
            }
        }
    }

    private static var possibleControllers: [(UIViewController & CameraStreamHandler).Type] { [
        CameraStreamHLSViewController.self,
        CameraStreamMJPEGViewController.self
    ] }

    private func viewController(
        from controllerPromises: [() -> Promise<UIViewController & CameraStreamHandler>]
    ) -> Promise<UIViewController & CameraStreamHandler> {
        var accumulatedErrors = [Error]()
        var promise: Promise<UIViewController & CameraStreamHandler> = .init(error:
            CameraViewControllerError.noControllers
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

        return promise.recover { (nextError) -> Promise<UIViewController & CameraStreamHandler> in
            throw CameraViewControllerError.accumulated(accumulatedErrors + [nextError])
        }
    }
}
