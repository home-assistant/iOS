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

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    var hud: MBProgressHUD?

    private var baseURL: String = ""

    let urlConfiguration: URLSessionConfiguration = URLSessionConfiguration.default

    var streamingController: MjpegStreamingController?

    override func viewDidLoad() {
        super.viewDidLoad()

        let keychain = Keychain(service: "io.robbie.homeassistant", accessGroup: "UTQFCBPQRF.io.robbie.HomeAssistant")
        if let url = keychain["baseURL"] {
            baseURL = url
        }
        if let pass = keychain["apiPassword"] {
            urlConfiguration.httpAdditionalHeaders = ["X-HA-Access": pass]
        }
    }

    func didReceive(_ notification: UNNotification) {
        print("Received a \(notification.request.content.categoryIdentifier) notification type")

        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.detailsLabel.text = "Loading \(notification.request.content.categoryIdentifier)..."
        hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
        self.hud = hud

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            self.showErrorLabel(message: "No entity_id found in payload!")
            return
        }
        guard let cameraProxyURL = URL(string: "\(baseURL)/api/camera_proxy_stream/\(entityId)") else {
            self.showErrorLabel(message: "Could not form a valid URL!")
            return
        }

        let imageView = UIImageView()
        imageView.frame = self.view.frame

        streamingController = MjpegStreamingController(imageView: imageView, contentURL: cameraProxyURL,
                                                       sessionConfiguration: urlConfiguration)
        streamingController?.gotNon200Status = { code in
            var labelText = "Unknown error!"
            switch code {
            case 401:
                labelText = "Authentication failed!"
            case 404:
                labelText = "Entity '\(entityId)' not found!"
            default:
                labelText = "Got non-200 status code (\(code))"
            }
            self.showErrorLabel(message: labelText)
        }
        streamingController?.didFinishLoading = {
            print("Finished loading")
            self.hud!.hide(animated: true)

            self.view.addSubview(imageView)
        }
        streamingController?.play()
        self.extensionContext?.mediaPlayingStarted()
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
        self.hud?.hide(animated: true)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 21))
        label.center.y = self.view.center.y
        label.textAlignment = .center
        label.textColor = .red
        label.text = message
        self.view.addSubview(label)
    }

}
