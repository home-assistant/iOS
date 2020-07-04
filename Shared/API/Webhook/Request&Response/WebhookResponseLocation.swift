import Foundation
import UserNotifications
import PromiseKit

extension WebhookResponseIdentifier {
    static var location: Self { .init(rawValue: "updateLocation") }
}

struct WebhookResponseLocation: WebhookResponseHandler {
    let api: HomeAssistantAPI
    init(api: HomeAssistantAPI) {
        self.api = api
    }

    static func shouldReplace(request current: URLSessionTask, with proposed: URLSessionTask) -> Bool {
        // recency should always win
        return true
    }

    func handle(result: Promise<Any>) -> Guarantee<WebhookResponseHandlerResult> {
        result.map { _ -> UNNotificationRequest? in
            // todo: this is't actually the right data
            let notificationOptions = LocationUpdateTrigger.BackgroundFetch.notificationOptionsFor(zoneName: "moo")
            Current.clientEventStore.addEvent(ClientEvent(text: notificationOptions.body, type: .locationUpdate,
                                                          payload: nil))
            if notificationOptions.shouldNotify {
                let content = UNMutableNotificationContent()
                content.title = notificationOptions.title
                content.body = notificationOptions.body
                content.sound = UNNotificationSound.default
                return .init(identifier: notificationOptions.identifier ?? "",
                             content: content, trigger: nil)

            } else {
                return nil
            }

            /*
             Current.Log.verbose("Device seen via webhook!")
             self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: payload)
             Current.logEvent?("location_update", ["trigger": updateType.rawValue as String])
             */
        }.recover { _ -> Guarantee<UNNotificationRequest?> in
            return .value(nil)
        }.map { notification in
            var result = WebhookResponseHandlerResult.default
            result.notification = notification
            return result
        }
    }
}
