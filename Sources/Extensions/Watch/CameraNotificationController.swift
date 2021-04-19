import Alamofire
import EMTLoadingIndicator
import Foundation
import PromiseKit
import Shared
import UserNotifications
import WatchKit

class CameraNotificationController: WKUserNotificationInterfaceController {
    @IBOutlet var notificationTitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationSubtitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationAlertLabel: WKInterfaceLabel!

    @IBOutlet var imageView: WKInterfaceImage!

    var streamer: MJPEGStreamer?

    var frameCount: Int = 0

    var shouldPlay: Bool = true {
        didSet {
            if !shouldPlay {
                Current.Log.verbose("Ending playback at frame #\(frameCount)")
                streamer?.cancel()
                streamer = nil
            }
        }
    }

    private var indicator: EMTLoadingIndicator?

    // MARK: - WKUserNotificationInterfaceController

    override func willActivate() {
        super.willActivate()

        indicator = EMTLoadingIndicator(
            interfaceController: self,
            interfaceImage: imageView,
            width: 40,
            height: 40,
            style: .dot
        )
        indicator?.prepareImagesForWait()
    }

    override func didAppear() {
        indicator?.showWait()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        shouldPlay = false
    }

    override func didReceive(_ notification: UNNotification) {
        notificationTitleLabel.setText(notification.request.content.title)
        notificationSubtitleLabel.setText(notification.request.content.subtitle)
        notificationAlertLabel!.setText(notification.request.content.body)

        if notificationActions.isEmpty {
            notificationActions = notification.request.content.userInfoActions
        }

        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else {
            Current.Log.error(L10n.Extensions.NotificationContent.Error.noEntityId)
            return
        }

        Current.api.done(on: nil) { [self] api in
            setup(streamer: api.VideoStreamer(), api: api, entityId: entityId)
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

        streamer.streamImages(fromURL: queryUrl) { image, error in
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
