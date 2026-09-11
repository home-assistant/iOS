import Foundation
import Shared
import UIKit
import UserNotifications

/// Warns the user when the app appears to have been force-closed (swiped away).
/// Two mechanisms, same notification identifier (adding a request replaces the
/// pending one, so at most one banner ever appears):
/// - Immediate (like Nextcloud): when the app is running in the background and
///   the user swipes it away, iOS calls `applicationWillTerminate`, where a
///   trigger-less notification is posted and delivered right away.
/// - Fallback: on backgrounding, schedule a notification a few
///   seconds out; while the app stays alive in the background, keep postponing
///   it. If the process is killed while suspended (no terminate callback),
///   postponing stops and the pending notification fires.
///
/// Only active when the user opts in via Location settings and the app has
/// Always location permission, which is what keeps the app alive in the background
/// (and what actually breaks when force-closed).
final class ForceCloseWarningManager {
    static let notificationIdentifier = "force-close-warning"
    static let fireAfter: TimeInterval = 10
    private static let rescheduleInterval: TimeInterval = 5

    private var rescheduleTimer: Timer?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelWarning),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func didEnterBackground() {
        guard Self.isEnabled else { return }
        scheduleWarning()
        startRescheduling()
    }

    @objc private func cancelWarning() {
        stopRescheduling()
        Current.userNotificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }

    private func startRescheduling() {
        stopRescheduling()
        rescheduleTimer = Timer.scheduledTimer(withTimeInterval: Self.rescheduleInterval, repeats: true) {
            [weak self] _ in
            self?.scheduleWarning()
        }
    }

    private func stopRescheduling() {
        rescheduleTimer?.invalidate()
        rescheduleTimer = nil
    }

    private func scheduleWarning() {
        let content = Self.makeContent(title: L10n.ForceCloseWarning.title, body: L10n.ForceCloseWarning.body)
        let request = Self.makeRequest(content: content, delay: Self.fireAfter)
        Current.userNotificationCenter.add(request)
    }

    /// Called from `applicationWillTerminate`: posts the warning for immediate
    /// delivery, replacing the pending fallback request (same identifier).
    /// The reschedule timer must be stopped first: the process lives for a few
    /// more seconds after terminate, and a timer fire then would re-arm the
    /// fallback on top of the immediate banner (double notification).
    func postImmediateWarning() {
        guard Self.isEnabled else { return }
        stopRescheduling()
        let center = Current.userNotificationCenter
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        let content = Self.makeContent(title: L10n.ForceCloseWarning.title, body: L10n.ForceCloseWarning.body)
        center.add(Self.makeImmediateRequest(content: content))
    }

    static var isEnabled: Bool {
        guard !Current.isCatalyst else { return false }
        guard Current.settingsStore.forceCloseWarningEnabled else { return false }
        return Current.settingsStore.isLocationEnabled(for: .background)
    }

    static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }

    static func makeRequest(content: UNNotificationContent, delay: TimeInterval) -> UNNotificationRequest {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        return UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
    }

    static func makeImmediateRequest(content: UNNotificationContent) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )
    }
}
