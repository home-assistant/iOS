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
import MBProgressHUD
import KeychainAccess
import Shared
import Alamofire
import AlamofireImage

class CameraViewController: UIView, NotificationCategory {
    private var baseURL: URL = Current.settingsStore.connectionInfo!.activeAPIURL

    let urlConfiguration: URLSessionConfiguration = URLSessionConfiguration.default

    var parentView: UIView = UIView(frame: .zero)

    var shouldPlay: Bool = true

    var streamer: MJPEGStreamer?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func didReceive(_ notification: UNNotification, vc: UIViewController, extensionContext: NSExtensionContext?,
                    hud: MBProgressHUD, completionHandler: @escaping (String?) -> Void) {

        vc.view.accessibilityIdentifier = "camera_notification"

        parentView = vc.view

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            completionHandler(L10n.Extensions.NotificationContent.Error.noEntityId)
            return
        }

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completionHandler(HomeAssistantAPI.APIError.notConfigured.localizedDescription)
            return
        }

        let imageView = UIImageView()

        var aspectRatioConstraint: NSLayoutConstraint?

        func updateAspectRatioConstraint(size: CGSize) {
            guard size.height > 0 else {
                return
            }

            let ratio = size.width/size.height

            guard aspectRatioConstraint?.multiplier != ratio else {
                return
            }

            let constraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: ratio)
            constraint.isActive = true
            aspectRatioConstraint = constraint
        }

        // assume we're going to be playing a 16:9 video, and adjust
        updateAspectRatioConstraint(size: CGSize(width: 16.0, height: 9.0))

        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityIdentifier = "camera_notification_imageview"

        var frameCount = 0

        guard let streamer = api.VideoStreamer() else {
            return
        }

        self.streamer = streamer
        let apiURL = api.connectionInfo.activeAPIURL
        let queryUrl = apiURL.appendingPathComponent("camera_proxy_stream/\(entityId)", isDirectory: false)

        streamer.streamImages(fromURL: queryUrl) { (image, error) in
            if let error = error, let afError = error as? AFError {
                Current.Log.error("Streaming image AFError: \(afError)")
                var labelText = L10n.Extensions.NotificationContent.Error.Request.unknown
                if let responseCode = afError.responseCode {
                    switch responseCode {
                    case 401:
                        labelText = L10n.Extensions.NotificationContent.Error.Request.authFailed
                    case 404:
                        labelText = L10n.Extensions.NotificationContent.Error.Request.entityNotFound(entityId)
                    default:
                        labelText = L10n.Extensions.NotificationContent.Error.Request.other(responseCode)
                    }
                }
                completionHandler(labelText)
            }

            if let image = image {
                defer {
                    frameCount += 1
                }
                if frameCount == 0 {
                    Current.Log.verbose("Got first frame!")

                    DispatchQueue.main.async(execute: {
                        hud.hide(animated: true)
                    })

                    if imageView.superview == nil {
                        vc.view.addSubview(imageView)
                        imageView.translatesAutoresizingMaskIntoConstraints = false
                        NSLayoutConstraint.activate([
                            imageView.topAnchor.constraint(equalTo: vc.view.topAnchor),
                            imageView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                            imageView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
                            imageView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
                        ])
                    }

                    extensionContext?.mediaPlayingStarted()
                }

                if self.shouldPlay {
                    image.accessibilityIdentifier = "camera_notification_image"
                    imageView.image = image
                    imageView.image?.accessibilityIdentifier = image.accessibilityIdentifier
                    
                    updateAspectRatioConstraint(size: image.size)
                }
            }

        }

        completionHandler(nil)
    }

    var isMediaExtension: Bool {
        return true
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        return .overlay
    }

    var mediaPlayPauseButtonFrame: CGRect {
        let centerX = Double(parentView.frame.width) / 2.0
        let centerY = Double(parentView.frame.height) / 2.0
        let buttonWidth = 50.0
        let buttonHeight = 50.0
        return CGRect(x: centerX - buttonWidth/2.0, y: centerY - buttonHeight/2.0,
                      width: buttonWidth, height: buttonHeight)
    }

    public func mediaPlay() {
        self.shouldPlay = true
    }

    public func mediaPause() {
        self.shouldPlay = false
    }

}
