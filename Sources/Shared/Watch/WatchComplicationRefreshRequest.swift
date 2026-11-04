#if os(iOS)
import Foundation

/// Asks the paired Apple Watch to fetch fresh values and re-render its complications.
///
/// The watch owns complication rendering: it reads the configs out of its mirrored database and
/// fetches each value from Home Assistant itself. Saving a complication on the iPhone therefore takes
/// two steps — get the new config across (the database mirror push) and then tell the watch to rebuild
/// from it. Without the second step the face keeps whatever it last rendered until the watch's own
/// periodic refresh comes around, which can be a long while after the user pressed Save.
///
/// Delivered as a complication user-info transfer (`transferCurrentComplicationUserInfo`), the channel
/// the system reserves for exactly this: it wakes the watch app in the background even when it isn't
/// reachable, and the watch's `complicationInfo` observer rebuilds every snapshot and reloads the
/// WidgetKit timelines. It is budgeted (a handful of high-priority wakes a day), so this is sent for
/// user-driven complication changes — not for every value update, which the watch polls on its own.
public enum WatchComplicationRefreshRequest {
    /// Key carrying when the request was made. The payload's only job is to be different from the last
    /// one: WatchConnectivity replaces a still-queued complication transfer with the newest, and an
    /// identical dictionary gives the watch no way to tell a fresh ask from a repeat.
    static let requestedAtKey = "requestedAt"

    /// Request a refresh. Safe to call when no watch is around — it just logs and returns.
    public static func send() {
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.verbose("Skip watch complication refresh request: watch unavailable")
            return
        }
        let info = HAWatchConnectivity.ComplicationInfo(content: [
            requestedAtKey: Current.date().timeIntervalSince1970,
        ])
        Communicator.shared.transfer(info) { result in
            switch result {
            case let .success(remaining):
                Current.Log.info("Requested watch complication refresh (\(remaining) transfers left today)")
            case let .failure(error):
                Current.Log.error("Watch complication refresh request failed: \(error.localizedDescription)")
            }
        }
    }
}
#endif
