import UserNotifications
import Shared
import PromiseKit

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        guard let api = Current.api() else {
            Current.Log.error("no available api, not attaching")
            contentHandler(request.content)
            return
        }

        NotificationAttachmentManager()
            .content(from: request.content, api: api)
            .done { contentHandler($0) }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        Current.Log.warning("serviceExtensionTimeWillExpire")
    }
}
