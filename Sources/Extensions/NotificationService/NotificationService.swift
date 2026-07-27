import PromiseKit
import Shared
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private let notificationCommunicationDecorator = NotificationCommunicationDecoratorImpl()
    private let commandManager = NotificationCommandManager()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Current.Log.info("didReceive \(request), user info \(request.content.userInfo)")

        if !Self.isLiveActivity(request.content.userInfo) {
            Current.notificationHistoryStore.record(NotificationHistoryEntry(content: request.content, kind: .remote))
        }

        Task {
            await forwardLiveActivityToAppIfNeeded(request.content.userInfo)
            await contentHandler(content(from: request.content))
        }
    }

    /// The remote flow has no app-side Live Activity handling unless the app is foregrounded:
    /// this extension can't touch ActivityKit, and an alert push never wakes the main app, so a
    /// backgrounded phone depends entirely on the server-side push-to-start path. Mirror the
    /// local-push flow's hand-off — the command manager, running in an extension, queues the
    /// start/update in the App Group and posts a Darwin signal. A running app applies it
    /// immediately (background updates are allowed); a suspended one drains it at next
    /// launch/foreground. Awaited so the queue write lands before the extension can be reaped.
    private func forwardLiveActivityToAppIfNeeded(_ userInfo: [AnyHashable: Any]) async {
        #if !targetEnvironment(macCatalyst)
        guard Self.isLiveActivity(userInfo) else { return }
        await withCheckedContinuation { continuation in
            commandManager.handle(userInfo).done {
                Current.Log.verbose("NotificationService: queued live activity hand-off for the app")
            }.ensure {
                continuation.resume()
            }.catch { error in
                Current.Log.error("NotificationService: live activity hand-off failed: \(error)")
            }
        }
        #endif
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
