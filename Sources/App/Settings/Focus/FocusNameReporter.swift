import Foundation
import Shared

/// Records which Focus is running and sends it to every server, whatever told us.
///
/// The Focus Filter is what iOS runs on its own, but it doesn't always run: a Focus that turns on
/// by schedule — Sleep at bedtime above all — can replace the running one without the filter
/// running and without the Focus status changing, which leaves the previous name reported until
/// something else reports one. Everything that can report a name goes through here so the filter
/// and the user's own reports are recorded identically.
enum FocusNameReporter {
    /// Where a report came from, kept in the logs so a name that was never reported can be told
    /// apart from one that was reported and then replaced.
    enum Source: String {
        /// iOS running the Focus Filter the user paired with a Focus.
        case focusFilter = "focus filter"
        /// The user's own report, from a Shortcuts automation or the Focus settings screen.
        case manual
    }

    static func report(name: String?, source: Source) async {
        Current.focusFilter.setActiveFocusName(name)
        Current.Log.info("focus name reported as \(name ?? "<none>") by \(source.rawValue)")
        // Client events outlive the app log, which rotates on launch: without this, a Focus change
        // iOS never told us about looks exactly like one whose report scrolled out of the log.
        Current.clientEventStore.addEvent(.init(
            text: "Focus name reported: \(name ?? "none")",
            type: .settings,
            payload: ["source": source.rawValue]
        ))

        for api in Current.apis {
            do {
                try await api.UpdateSensors(trigger: .Signaled).async(timeout: 10)
            } catch {
                Current.Log.error("focus name report failed to update sensors on \(api.server.info.name): \(error)")
            }
        }
    }
}
