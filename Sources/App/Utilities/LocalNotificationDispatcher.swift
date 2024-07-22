import Foundation
import Shared
import UserNotifications

protocol LocalNotificationDispatcherProtocol {
    func send(_ notification: LocalNotificationDispatcher.Notification)
}

/// Sends local notifications
final class LocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    struct Notification {
        let id: NotificationIdentifier
        let title: String
        let body: String?
        let sound: UNNotificationSound?

        init(
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

    func send(_ notification: Notification) {
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
