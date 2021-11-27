import PromiseKit
import Shared
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        guard let server = Current.servers.server(for: request.content) else {
            contentHandler(request.content)
            return
        }

        firstly {
            Current.notificationAttachmentManager.content(from: request.content, api: Current.api(for: server))
        }.recover { error in
            Current.Log.error("failed to get content, giving default: \(error)")
            return .value(request.content)
        }.done {
            contentHandler($0)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        Current.Log.warning("serviceExtensionTimeWillExpire")
    }
}
