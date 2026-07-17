import PromiseKit
import Shared
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private let notificationCommunicationDecorator = NotificationCommunicationDecoratorImpl()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        if !Self.isLiveActivity(request.content.userInfo) {
            Current.notificationHistoryStore.record(NotificationHistoryEntry(content: request.content, kind: .remote))
        }

        Task {
            await contentHandler(content(from: request.content))
        }
    }

    private func content(from originalContent: UNNotificationContent) async -> UNNotificationContent {
        guard let server = Current.servers.server(for: originalContent),
              let api = Current.api(for: server) else {
            guard let sender = NotificationSenderParser.parse(from: originalContent) else {
                return originalContent
            }
            return await notificationCommunicationDecorator.decorate(
                content: originalContent,
                sender: sender,
                api: nil
            )
        }

        let content = await withCheckedContinuation { continuation in
            Current.notificationAttachmentManager.content(from: originalContent, api: api).done {
                continuation.resume(returning: $0)
            }
        }
        guard let sender = NotificationSenderParser.parse(from: content) else { return content }
        return await notificationCommunicationDecorator.decorate(content: content, sender: sender, api: api)
    }

    private static func isLiveActivity(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["live_update"] as? Bool) == true || (hadict["command"] as? String) == "live_activity"
    }

    override func serviceExtensionTimeWillExpire() {
        Current.Log.warning("serviceExtensionTimeWillExpire")
    }
}
