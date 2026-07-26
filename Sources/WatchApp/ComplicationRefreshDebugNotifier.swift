import Shared
import UserNotifications

/// Posts local notifications tracing complication reloads (self fetch) while the developer option in
/// Settings → Troubleshooting → Developer is enabled: one when a reload starts and one when it
/// finishes, saying whether each complication succeeded and why it failed. Makes background reloads
/// observable on the wrist without a tethered debugger; off by default, so regular users never see
/// these.
enum ComplicationRefreshDebugNotifier {
    static func notifyStarted(count: Int) {
        guard WatchUserDefaults.shared.complicationRefreshNotificationsEnabled else { return }
        post(
            title: L10n.Watch.Debug.ComplicationRefresh.Started.title,
            body: L10n.Watch.Debug.ComplicationRefresh.Started.body(count)
        )
    }

    static func notifyFinished(_ outcomes: [ComplicationRefreshOutcome]) {
        guard WatchUserDefaults.shared.complicationRefreshNotificationsEnabled else { return }
        let succeeded = outcomes.filter { $0.status == .live }.count
        var lines = [L10n.Watch.Debug.ComplicationRefresh.Finished.summary(succeeded, outcomes.count - succeeded)]
        // One line per non-live complication: a cached outcome also failed its live fetch — the
        // face just keeps showing the previous value instead of going blank.
        for outcome in outcomes where outcome.status != .live {
            let reason = outcome.reason ?? L10n.Watch.Debug.ComplicationRefresh.Finished.unknownReason
            if outcome.status == .cached {
                lines.append(L10n.Watch.Debug.ComplicationRefresh.Finished.keptPreviousLine(outcome.name, reason))
            } else {
                lines.append(L10n.Watch.Debug.ComplicationRefresh.Finished.failedLine(outcome.name, reason))
            }
        }
        post(
            title: L10n.Watch.Debug.ComplicationRefresh.Finished.title,
            body: lines.joined(separator: "\n")
        )
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }
}
