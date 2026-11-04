import Foundation
@testable import Shared
import UserNotifications

final class MockLocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    private var lastNotificationSent: LocalNotificationDispatcher.Notification?
    private(set) var lastRescheduledContent: UNNotificationContent?
    private(set) var lastRescheduledDelay: TimeInterval?

    func send(_ notification: LocalNotificationDispatcher.Notification) {
        lastNotificationSent = notification
    }

    func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {
        lastRescheduledContent = content
        lastRescheduledDelay = delay
    }
}
