import Foundation
@testable import Shared
import UserNotifications

final class MockLocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    private(set) var sentNotifications: [LocalNotificationDispatcher.Notification] = []
    private(set) var lastRescheduledContent: UNNotificationContent?
    private(set) var lastRescheduledDelay: TimeInterval?

    func send(_ notification: LocalNotificationDispatcher.Notification, completion: (() -> Void)?) {
        sentNotifications.append(notification)
        completion?()
    }

    func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {
        lastRescheduledContent = content
        lastRescheduledDelay = delay
    }
}
