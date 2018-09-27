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
import KeychainAccess
import Shared
import Alamofire
import AlamofireImage

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    var hud: MBProgressHUD?

    private var baseURL: URL = Current.settingsStore.connectionInfo!.activeAPIURL

    let urlConfiguration: URLSessionConfiguration = URLSessionConfiguration.default

    var streamingController: MjpegStreamingController?

    func didReceive(_ notification: UNNotification) {
        print("Received a \(notification.request.content.categoryIdentifier) notification type")

        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        let loadTxt = L10n.Extensions.NotificationContent.Hud.loading(notification.request.content.categoryIdentifier)
        hud.detailsLabel.text = loadTxt
        hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
        self.hud = hud

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            self.showErrorLabel(message: L10n.Extensions.NotificationContent.Error.noEntityId)
            return
        }
//        guard let cameraProxyURL = baseURL.appendPathComponent("camera_proxy_stream/\(entityId)") else {
//            self.showErrorLabel(message: "Could not form a valid URL!")
//            return
//        }

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        let imageView = UIImageView()
        imageView.frame = self.view.frame

        var frameCount = 0

        api.GetCameraStream(cameraEntityID: entityId) { image, error in
            if let error = error, let afError = error as? AFError {
                print("afError", afError)
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
                return
            }

            if let image = image {
                if frameCount == 0 {
                    print("Got first frame!")

                    print("Finished loading")

                    DispatchQueue.main.async(execute: {
                        self.hud!.hide(animated: true)
                    })

                    self.view.addSubview(imageView)

                    //            streamingController?.play()
                    self.extensionContext?.mediaPlayingStarted()
                }

                frameCount += 1

                print("FRAME", frameCount)

                DispatchQueue.main.async {
                    imageView.image = image
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
        streamingController?.play()
    }

    public func mediaPause() {
        streamingController?.stop()
    }

    func showErrorLabel(message: String) {
        self.extensionContext?.mediaPlayingStarted()
        DispatchQueue.main.async(execute: {
            self.hud!.hide(animated: true)
        })
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 21))
        label.center.y = self.view.center.y
        label.textAlignment = .center
        label.textColor = .red
        label.text = message
        self.view.addSubview(label)
    }

}
