import Foundation

/// Finishes dismissals that never reached Home Assistant.
///
/// Stopping cannot wait for the network, so a dismissal is best effort at the moment the user
/// stops. That is the right trade for the user and the wrong one for the server, which would go on
/// pushing to a session that has ended until APNs starts rejecting its token. This closes the gap
/// from the other side: what is still owed is written down, and a later launch sends it.
///
/// Deliberately not a timer. Live Activities in this app take the same shape — the token report is
/// the part worth retrying hard, and the cleanup is reconciled when the app next runs — and a
/// process that wakes on its own schedule to retry a courtesy message is not worth the battery.
///
/// Host app only. The RemoteMedia extension has a 6144 KB ledger and no business knowing about
/// relationships other than its own, so nothing here is reachable from it.
@MainActor
public enum RemoteMediaDismissalReconciler {
    /// The sender used in production; replaced in tests.
    public static var sender = RemoteMediaDismissalSender()

    /// Sends whatever is still owed, and forgets what the server accepts.
    ///
    /// A record whose server has been removed from the app is dropped: there is nothing left to
    /// tell, and the registration goes with the config entry whenever the user removes it in Home
    /// Assistant. A record whose server is configured but unreachable is kept for next time.
    public static func reconcile() async {
        let store = Current.settingsStore
        let pending = store.remoteMediaPendingDismissals
        guard !pending.isEmpty else { return }

        for record in pending {
            guard let server = Current.servers.server(forServerIdentifier: record.serverId) else {
                RemoteMediaLog.logger.info(
                    """
                    RemoteMedia dismissal session=\(record.sessionId, privacy: .public) \
                    result=server no longer configured, dropping
                    """
                )
                store.removeRemoteMediaPendingDismissal(record)
                continue
            }
            // Rebuilt from the server as it is configured now rather than from anything stored:
            // the webhook secret and the routes are exactly what must not be persisted.
            let context = RemoteMediaTransportContextWriter.context(
                for: .init(serverId: record.serverId, entityId: record.entityId),
                server: server
            )
            guard let end = RemoteMediaFollowEnd.resuming(record, context: context) else { continue }
            if await sender.send(end) {
                store.removeRemoteMediaPendingDismissal(record)
            }
        }
    }
}
