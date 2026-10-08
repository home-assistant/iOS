import Foundation

/// What is known about the cover of the track a snapshot shows: none offered, one that exists but is not
/// prepared yet, or where the prepared copy is.
public enum RemoteMediaArtwork: Equatable, Sendable {
    /// No picture was offered. This describes a report, not the track: Home Assistant leaves
    /// `entity_picture` out both when there is no picture and while an integration refreshes, so it is
    /// never treated as a removal (see `RemoteMediaSnapshotReducer`).
    case absent
    /// A cover exists but is not prepared. `RemoteMediaEntityState.artworkSource` says where to get it.
    case deferred
    /// A prepared copy, in the cache the app shares with the extension under this key. Never read from
    /// Home Assistant; `RemoteMediaEntityState.displayedSnapshot` is the only thing that produces one.
    case available(cacheKey: RemoteMediaDigest)
}
