import Shared
import UserNotifications

/// Posts local notifications tracing complication reloads (self fetch) while the developer option in
/// Settings → Troubleshooting → Developer is enabled: one when a reload starts and one when it
/// finishes, saying whether each complication succeeded and why it failed. Makes background reloads
/// observable on the wrist without a tethered debugger; off by default, so regular users never see
/// these.
enum ComplicationRefreshDebugNotifier {
    static func notifyStarted(names: [String]) {
        guard WatchUserDefaults.shared.complicationRefreshNotificationsEnabled else { return }
        post(
            title: L10n.Watch.Debug.ComplicationRefresh.Started.title,
            body: L10n.Watch.Debug.ComplicationRefresh.Started.body(names.count, names.joined(separator: ", "))
        )
    }

    static func notifyFinished(_ outcomes: [ComplicationRefreshOutcome], duration: TimeInterval) {
        guard WatchUserDefaults.shared.complicationRefreshNotificationsEnabled else { return }
        let succeeded = outcomes.filter { $0.status == .live }.count
        // A summary line, then one line per complication — updated value and fetch time for
        // successes, elapsed time and cause for failures — so the notification alone tells the
        // whole story of the reload.
        var lines = [L10n.Watch.Debug.ComplicationRefresh.Finished.summary(
            succeeded,
            outcomes.count - succeeded,
            seconds(duration)
        )]
        lines.append(contentsOf: outcomes.map(line(for:)))
        post(
            title: L10n.Watch.Debug.ComplicationRefresh.Finished.title,
            body: lines.joined(separator: "\n")
        )
    }

    private static func line(for outcome: ComplicationRefreshOutcome) -> String {
        let label = outcome.entityId.map { "\(outcome.name) (\($0))" } ?? outcome.name
        let duration = seconds(outcome.duration)
        let reason = outcome.reason ?? L10n.Watch.Debug.ComplicationRefresh.Finished.unknownReason
        switch outcome.status {
        case .live:
            return L10n.Watch.Debug.ComplicationRefresh.Finished.updatedLine(
                label,
                outcome.value ?? "",
                duration
            )
        case .cached:
            // A cached outcome also failed its live fetch — the face just keeps showing the
            // previous value instead of going blank.
            return L10n.Watch.Debug.ComplicationRefresh.Finished.keptPreviousLine(
                label,
                duration,
                reason,
                outcome.value ?? ""
            )
        case .failed:
            return L10n.Watch.Debug.ComplicationRefresh.Finished.failedLine(label, duration, reason)
        }
    }

    private static func seconds(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", interval)
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
            // Never affects the refresh itself; surfacing the error explains a silent toggle (e.g.
            // notifications not authorized on this watch).
            if let error {
                Current.Log.error("Failed to post complication refresh debug notification: \(error)")
            }
        }
    }
}
