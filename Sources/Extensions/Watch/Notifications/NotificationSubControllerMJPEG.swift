import Foundation
import PromiseKit
import Shared
import UserNotifications
import WatchKit

class NotificationSubControllerMJPEG: NotificationSubController {
    let entityId: String
    let api: HomeAssistantAPI

    required init?(api: HomeAssistantAPI, notification: UNNotification) {
        guard let entityId = notification.request.content.userInfo["entity_id"] as? String,
              entityId.starts(with: "camera.") else {
            return nil
        }

        self.api = api
        self.entityId = entityId
    }

    required init?(api: HomeAssistantAPI, url: URL) {
        nil
    }

    private var streamer: MJPEGStreamer?

    func start(with elements: NotificationElements) -> Promise<Void> {
        elements.image.setHidden(true)

        let streamer = api.VideoStreamer()
        self.streamer = streamer

        return Promise<Void> { seal in
            let apiURL = api.server.info.connection.activeAPIURL()
            let queryUrl = apiURL.appendingPathComponent("camera_proxy_stream/\(entityId)", isDirectory: false)

            streamer.streamImages(fromURL: queryUrl) { uiImage, error in
                if let error = error {
                    seal.reject(error)
                } else if let uiImage = uiImage {
                    seal.fulfill(())
                    elements.image.setHidden(false)
                    elements.image.setImage(uiImage)
                }
            }
        }
    }

    func stop() {
        streamer?.cancel()
        streamer = nil
    }
}
