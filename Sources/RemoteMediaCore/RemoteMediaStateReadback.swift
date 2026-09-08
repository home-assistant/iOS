import Foundation

/// The outcome of reading one player's state back through `render_template`.
public enum RemoteMediaStateReadback: Equatable, Sendable {
    case entity(RemoteMediaEntityState)
    /// The entity no longer exists on the server. One of the few genuinely terminal conditions for
    /// a followed selection.
    case missing
    /// The response arrived but could not be understood, which is a transport problem rather than
    /// a statement about the player, so the session is left alone.
    case unreadable
}
