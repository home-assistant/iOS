import Foundation

/// Everything a dismissal needs, captured before the state it needs is torn down.
///
/// Stopping is a user action, so the local session ends immediately and the request goes out
/// afterwards — which means the identity and the transport it depends on have to be taken while
/// they still describe the relationship that is ending. The webhook secret in particular is cleared
/// as part of no longer following, so reading it after the fact would find nothing.
///
/// The identity half is also what gets persisted, so a request that never lands can be finished by
/// a later launch. See `RemoteMediaPendingDismissal`.
public struct RemoteMediaFollowEnd: Equatable, Sendable {
    public let pending: RemoteMediaPendingDismissal
    public let context: RemoteMediaTransportContext

    public var dismissal: RemoteMediaSessionDismissal { pending.dismissal }
    public var serverId: String { pending.serverId }

    public init(pending: RemoteMediaPendingDismissal, context: RemoteMediaTransportContext) {
        self.pending = pending
        self.context = context
    }

    /// The relationship that is ending, or `nil` when there is nothing to retire.
    ///
    /// Nothing is owed to the server when no player was being followed, when the relationship has
    /// no complete lifetime — an older build's state, which the server could not order anyway —
    /// when the routes and secret it would be sent with are gone, or when the stored context
    /// describes some other player, which would mean sending one relationship's dismissal
    /// authenticated as another's.
    public static func capture(
        selection: RemoteMediaSelection?,
        lifetime: RemoteMediaFollowLifetime?,
        context: RemoteMediaTransportContext?
    ) -> RemoteMediaFollowEnd? {
        guard let selection, let lifetime, let context, context.selection == selection else {
            return nil
        }
        return .init(
            pending: .init(selection: selection, lifetime: lifetime),
            context: context
        )
    }

    /// A retry of a dismissal that was persisted earlier, against the server as it is configured
    /// now. Refused when the rebuilt transport belongs to a different server.
    public static func resuming(
        _ pending: RemoteMediaPendingDismissal,
        context: RemoteMediaTransportContext
    ) -> RemoteMediaFollowEnd? {
        guard context.selection.serverId == pending.serverId else { return nil }
        return .init(pending: pending, context: context)
    }
}
