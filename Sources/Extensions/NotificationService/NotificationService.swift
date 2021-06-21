import PromiseKit
import Shared
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    class Pending {
        internal init(content: UNNotificationContent, handler: @escaping (UNNotificationContent) -> Void) {
            self.content = content
            self.handler = handler
        }

        var content: UNNotificationContent
        var handler: (UNNotificationContent) -> Void
    }

    private var pending: Pending?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        let pending = Pending(content: request.content, handler: contentHandler)
        self.pending = pending

        firstly {
            Current.notificationAttachmentManager.decryptContent(fromUserInfo: request.content.userInfo)
        }.recover { error in
            Current.Log.error("failed to decrypt content, giving default: \(error)")
            return .value(request.content)
        }.get {
            pending.content = $0
        }.then { withoutAttachment in
            Current.api.then(on: nil) { api in
                Current.notificationAttachmentManager.content(from: withoutAttachment, api: api)
            }.recover { error in
                Current.Log.error("failed to get content, giving default: \(error)")
                return .value(withoutAttachment)
            }
        }.done { [weak self] content in
            Current.Log.info("providing body \(content.body)")
            contentHandler(content)
            self?.pending = nil
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        if let pending = pending {
            Current.Log.info("sending content")
            pending.handler(pending.content)
        } else {
            Current.Log.error("missing content at expiration time")
        }

        pending = nil
    }
}
