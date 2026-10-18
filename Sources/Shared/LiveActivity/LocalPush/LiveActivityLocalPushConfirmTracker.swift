#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Extension-side bookkeeping for Live Activity pushes whose receipt confirm waits on the app.
///
/// The PushProvider extension cannot start a Live Activity, and the app can only do so while it is
/// in the foreground. So a `live_update` push is handed to the app and its confirm is held here
/// until the app replies through `LiveActivityLocalPushResult`: `presented` confirms the push;
/// `notPresented`, or no reply within `replyTimeout` (the app is suspended), re-opens the channel
/// instead. The server tears the old channel down first, which re-sends every unconfirmed push
/// through APNs, where push-to-start reaches a backgrounded app, and registers the new channel in
/// the same request, so local push never goes quiet. Main-thread confined.
final class LiveActivityLocalPushConfirmTracker {
    /// How long the app gets to reply. A running app answers within milliseconds; silence means it
    /// is suspended. Must stay well under the server's own 10 s confirm timeout.
    var replyTimeout: TimeInterval = 2

    /// Confirms receipt of the push with the given confirm id.
    var confirm: (String) -> Void = { _ in }
    /// Re-opens the channel so the server fails every unconfirmed push over to APNs.
    var reopenChannel: () -> Void = {}

    private struct Pending {
        let tag: String
        let deadline: DispatchTime
        let timeout: DispatchWorkItem
    }

    private var pending: [String: Pending] = [:]

    var pendingConfirmIDs: Set<String> {
        Set(pending.keys)
    }

    init() {
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // C callback can't capture self; re-derive it (see LiveActivityPendingStartObserver).
            guard let observer else { return }
            let tracker = Unmanaged<LiveActivityLocalPushConfirmTracker>.fromOpaque(observer)
                .takeUnretainedValue()
            DispatchQueue.main.async {
                tracker.handleResults()
            }
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            LiveActivityLocalPushResult.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
        for entry in pending.values {
            entry.timeout.cancel()
        }
    }

    /// Hold the confirm for `confirmID` until the app replies or `replyTimeout` passes.
    func track(confirmID: String, tag: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // A newer push for a tag that is already waiting keeps that tag's deadline, so a stream of
            // updates to a suspended app cannot postpone the fallback forever.
            let deadline = pending.values.first { $0.tag == tag }?.deadline ?? DispatchTime.now() + replyTimeout
            // The hand-off queue keeps only the newest start per tag, so the app never replies for
            // an older one; its content is stale either way, so release it now.
            releaseSuperseded(tag: tag)
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, pending[confirmID] != nil else { return }
                Current.Log.info("local push: no reply from the app for Live Activity \(tag), re-sending via APNs")
                fallBack()
            }
            pending[confirmID] = Pending(tag: tag, deadline: deadline, timeout: timeout)
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: timeout)
            // The app may have replied before this registration ran.
            handleResults()
        }
    }

    /// Confirm any pending push for `tag` without waiting for the app: a newer start or an end for
    /// the same tag has made it moot, and re-sending it through APNs would resurrect stale content.
    func confirmSuperseded(tag: String) {
        DispatchQueue.main.async { [weak self] in
            self?.releaseSuperseded(tag: tag)
        }
    }

    private func releaseSuperseded(tag: String) {
        for (confirmID, entry) in pending where entry.tag == tag {
            entry.timeout.cancel()
            pending.removeValue(forKey: confirmID)
            confirm(confirmID)
        }
    }

    func handleResults() {
        guard !pending.isEmpty else { return }
        let results = LiveActivityLocalPushResult.take(confirmIDs: pendingConfirmIDs)
        for (confirmID, outcome) in results where outcome == .presented {
            guard let entry = pending.removeValue(forKey: confirmID) else { continue }
            entry.timeout.cancel()
            confirm(confirmID)
        }
        if results.values.contains(.notPresented) {
            // The app is alive but in the background, so ActivityKit refused the start.
            Current.Log.info("local push: app could not present the Live Activity, re-sending via APNs")
            fallBack()
        }
    }

    /// Re-open the channel. The server re-sends every push still unconfirmed, so all pending
    /// entries are released and their queued starts dropped: APNs owns them now.
    private func fallBack() {
        for entry in pending.values {
            entry.timeout.cancel()
            if #available(iOS 17.2, *) {
                LiveActivityPendingStart.remove(tag: entry.tag)
            }
        }
        pending.removeAll()
        reopenChannel()
    }
}
#endif
