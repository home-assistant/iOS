import Foundation

/// Where a track's cover can be fetched: the entity's `entity_picture_local` when it has one, else its
/// `entity_picture`, verbatim.
///
/// `entity_picture_local` is a Home Assistant proxy path, so it is relative to the server that reported
/// it and has to be resolved against that server, not any other. `entity_picture` is only the fallback
/// and may be an absolute URL on another host. Either way the query can carry an access token, so
/// callers must treat `reference` as credential-like data, fetch it only through the app's own
/// authenticated connection, and not log or persist it. This type keeps it out of
/// `RemoteMediaSnapshot`, and `description` and `debugDescription` do not expose it; those are its only
/// guarantees.
///
/// A source also records the player (server and entity) and the track it was reported for, because a
/// proxy path is relative to its server and one address can serve different images. Two sources are
/// equal only when all three match, which is how a changed cover is noticed: what was prepared from an
/// old source stops applying. Equality can be stricter than the picture; if Home Assistant re-issues
/// its proxy token, the same picture is fetched once more.
public struct RemoteMediaArtworkSource: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The chosen picture exactly as the entity reported it: a server-relative path or an absolute URL.
    public let reference: String
    /// The player scope of the state it was reported in (`RemoteMediaEntityState.playerScope`).
    private let scope: RemoteMediaDigest
    /// `RemoteMediaTrack.cacheIdentity` of the track when this source was created.
    private let track: RemoteMediaDigest

    init(_ reference: String, scope: RemoteMediaDigest, track: RemoteMediaDigest) {
        self.reference = reference
        self.scope = scope
        self.track = track
    }

    /// Names this source's prepared copy in the cache shared by the app and the extension. A digest, so
    /// it does not embed the plaintext reference, server or entity, though equal inputs still give equal
    /// keys. It covers the player and track as well as the picture, since the extension takes a changed
    /// key to mean a changed cover. It reflects the track fields known when the source was created, so
    /// the same media first reported with different fields can get a different key and cost one extra
    /// fetch; it is never a reason to show the wrong cover.
    public var cacheKey: RemoteMediaDigest {
        RemoteMediaDigest(hashingFields: [scope.hexString, track.hexString, reference])
    }

    public var description: String { "RemoteMediaArtworkSource" }
    public var debugDescription: String { description }
}
