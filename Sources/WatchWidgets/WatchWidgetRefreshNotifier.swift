import Foundation
import UserNotifications

/// Posts local notifications tracing the widget's own complication self fetch while the developer
/// option (watch Settings → Troubleshooting → Developer) is enabled. The widget extension has no UI
/// of its own, so notifications are the only way to observe when WidgetKit actually runs a refresh
/// and whether the fetch succeeded or why it failed. Off by default; best-effort — if the system
/// declines to deliver from the extension, the refresh itself is unaffected.
enum WatchWidgetRefreshNotifier {
    // Unlocalized on purpose: the widget target carries no strings tables (see the plain-text
    // constants in `WatchWidgetConstants`), and this developer-only tracing never shows for
    // regular users.
    static func notifyStarted(configuredID: String?) {
        post(
            title: "Widget reload started",
            body: configuredID == nil ? "Self fetch: all complications" : "Self fetch: one complication"
        )
    }

    static func notifyFinished(_ summary: String) {
        post(title: "Widget reload finished", body: summary)
    }

    private static func post(title: String, body: String) {
        guard UserDefaults(suiteName: WatchWidgetConstants.appGroupID)?
            .bool(forKey: WatchWidgetConstants.refreshNotificationsKey) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }
}
