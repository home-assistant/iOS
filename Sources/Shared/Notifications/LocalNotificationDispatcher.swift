import Foundation
import UserNotifications

public protocol LocalNotificationDispatcherProtocol {
    func send(_ notification: LocalNotificationDispatcher.Notification)
}

/// Sends local notifications
public final class LocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    public struct Notification {
        public let id: NotificationIdentifier
        public let title: String
        public let body: String?
        public let sound: UNNotificationSound?

        public init(
            id: NotificationIdentifier,
            title: String,
            body: String? = nil,
            sound: UNNotificationSound? = nil
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.sound = sound
        }
    }

    public init() {}

    public func send(_ notification: Notification) {
        if notification.id == .debug, !Current.settingsStore.receiveDebugNotifications {
            // Do not send debug notifications if the setting is disabled
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        if let body = notification.body {
            content.body = body
        }
        content.sound = notification.sound
        let request = UNNotificationRequest(
            identifier: notification.id.rawValue,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log
                    .info("Error scheduling notification, id: \(notification.id) error: \(error.localizedDescription)")
            }
        }
    }
}
