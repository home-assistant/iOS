//
//  NotificationViewController.swift
//  NotificationContentExtension
//
//  Created by Robbie Trencheny on 9/9/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MBProgressHUD
import Shared
import Alamofire

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    var hud: MBProgressHUD?

    var shouldPlay: Bool = true

    var streamer: MJPEGStreamer?

    func didReceive(_ notification: UNNotification) {
        print("Received a \(notification.request.content.categoryIdentifier) notification type")

        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.detailsLabel.text = "Loading \(notification.request.content.categoryIdentifier)..."
        hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
        self.hud = hud

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            self.showErrorLabel(message: L10n.Extensions.NotificationContent.Error.noEntityId)
            return
        }

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            self.showErrorLabel(message: HomeAssistantAPI.APIError.notConfigured.localizedDescription)
            return
        }

        let imageView = UIImageView()
        imageView.frame = self.view.frame
        // Needed for UI Automation w/ Fastlane Snapshot
        imageView.accessibilityIdentifier = "camera_notification_imageview"

        var frameCount = 0

        guard let streamer = api.videoStreamer() else {
            return
        }

        self.streamer = streamer
        let apiURL = api.connectionInfo.activeAPIURL
        let queryUrl = apiURL.appendingPathComponent("camera_proxy_stream/\(entityId)", isDirectory: false)

        streamer.streamImages(fromURL: queryUrl) { (image, error) in
            if let error = error, let afError = error as? AFError {
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
                self.showErrorLabel(message: labelText)
            }

            if let image = image {
                defer {
                    frameCount += 1
                    print("FRAME", frameCount)
                }

                if frameCount == 0 {
                    print("Got first frame!")

                    print("Finished loading")

                    DispatchQueue.main.async(execute: {
                        hud.hide(animated: true)
                    })

                    self.view.addSubview(imageView)
                    self.extensionContext?.mediaPlayingStarted()
                }

                if self.shouldPlay {
                    image.accessibilityIdentifier = "camera_notification_image"
                    imageView.image = image
                    imageView.image?.accessibilityIdentifier = image.accessibilityIdentifier
                }

            }

        }
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        return .overlay
    }

    var mediaPlayPauseButtonFrame: CGRect {
        let centerX = Double(view.frame.width) / 2.0
        let centerY = Double(view.frame.height) / 2.0
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

    func showErrorLabel(message: String) {
        print("Error while showing camera!", message)
        self.extensionContext?.mediaPlayingStarted()
        self.hud?.hide(animated: true)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 21))
        label.center.y = self.view.center.y
        label.textAlignment = .center
        label.textColor = .red
        label.text = message
        self.view.addSubview(label)
    }

}
