//
//  CameraNotificationController.swift
//  WatchAppExtension
//
//  Created by Robert Trencheny on 2/27/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications
import Shared
import Alamofire
import EMTLoadingIndicator
import PromiseKit

class CameraNotificationController: WKUserNotificationInterfaceController {

    @IBOutlet weak var notificationTitleLabel: WKInterfaceLabel!
    @IBOutlet weak var notificationSubtitleLabel: WKInterfaceLabel!
    @IBOutlet weak var notificationAlertLabel: WKInterfaceLabel!

    @IBOutlet weak var imageView: WKInterfaceImage!

    var streamer: MJPEGStreamer?

    var frameCount: Int = 0

    var shouldPlay: Bool = true {
        didSet {
            if !self.shouldPlay {
                Current.Log.verbose("Ending playback at frame #\(frameCount)")
                self.streamer?.cancel()
                self.streamer = nil
            }
        }
    }

    private var indicator: EMTLoadingIndicator?

    // MARK: - WKUserNotificationInterfaceController

    override func willActivate() {
        super.willActivate()

        indicator = EMTLoadingIndicator(interfaceController: self, interfaceImage: self.imageView, width: 40,
                                        height: 40, style: .dot)
        indicator?.prepareImagesForWait()
    }

    override func didAppear() {
        indicator?.showWait()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        self.shouldPlay = false
    }

    override func didReceive(_ notification: UNNotification) {
        self.notificationTitleLabel.setText(notification.request.content.title)
        self.notificationSubtitleLabel.setText(notification.request.content.subtitle)
        self.notificationAlertLabel!.setText(notification.request.content.body)

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            Current.Log.error(L10n.Extensions.NotificationContent.Error.noEntityId)
            return
        }

        Current.api.compactMap { api in
            if let streamer = api.VideoStreamer() {
                return (streamer, api)
            } else {
                return nil
            }
        }.done { [self] streamer, api in
            setup(streamer: streamer, api: api, entityId: entityId)
        }.cauterize()
    }

    private func setup(streamer: MJPEGStreamer, api: HomeAssistantAPI, entityId: String) {
        guard let connectionInfo = try? api.connectionInfo() else {
            Current.Log.error("no connection info available")
            return
        }

        self.streamer = streamer

        let apiURL = connectionInfo.activeAPIURL
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
                Current.Log.error(labelText)
            }

            if let image = image {
                defer {
                    self.frameCount += 1
                }

                Current.Log.verbose("Frame #\(self.frameCount)")

                self.imageView.setImage(image)
            }
        }
    }
}
