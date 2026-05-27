import PromiseKit
import Shared
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        guard let server = Current.servers.server(for: request.content),
              let api = Current.api(for: server) else {
            contentHandler(request.content)
            return
        }

        firstly {
            Current.notificationAttachmentManager.content(from: request.content, api: api)
        }.recover { error -> Guarantee<UNNotificationContent> in
            Current.Log.error("failed to get content, giving default: \(error)")
            return .value(request.content)
        }.then { content -> Guarantee<UNNotificationContent> in
            guard let sender = NotificationSenderParser.parse(from: content) else {
                return .value(content)
            }
            return Current.notificationCommunicationDecorator
                .decorate(content: content, sender: sender, api: api)
        }.done {
            contentHandler($0)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        Current.Log.warning("serviceExtensionTimeWillExpire")
    }
}
