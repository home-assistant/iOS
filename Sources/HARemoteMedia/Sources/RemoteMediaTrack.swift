import Foundation

/// The media a player is playing. A track exists only when something identifies it (`title`, `artist`,
/// `album` or `contentKey`); a duration or picture alone is no evidence of one, since players report
/// those while changing track, so such a report has no track and a snapshot says so with `track == nil`.
///
/// Wherever one is built, values are normalized the same way: empty strings are missing, `duration` is
/// positive, and a `position` that is not finite, is negative or is past a known `duration` is dropped
/// rather than rewritten, along with its timestamp (a timestamp means nothing without its position).
public struct RemoteMediaTrack: Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    /// A digest of `media_content_id`, which can be a signed stream URL and so is not carried itself.
    public let contentKey: RemoteMediaDigest?
    /// Seconds. Always positive.
    public let duration: TimeInterval?
    /// Seconds into the track, as of `positionUpdatedAtUnix`. Never negative, never past `duration`.
    public let position: TimeInterval?
    /// When `position` was measured, in seconds since 1970-01-01 UTC.
    public let positionUpdatedAtUnix: TimeInterval?
    public let artwork: RemoteMediaArtwork

    init?(
        title: String?,
        artist: String?,
        album: String?,
        contentKey: RemoteMediaDigest?,
        duration: TimeInterval?,
        position: TimeInterval?,
        positionUpdatedAtUnix: TimeInterval?,
        artwork: RemoteMediaArtwork
    ) {
        let title = title.flatMap { $0.isEmpty ? nil : $0 }
        let artist = artist.flatMap { $0.isEmpty ? nil : $0 }
        let album = album.flatMap { $0.isEmpty ? nil : $0 }
        let duration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        guard title != nil || artist != nil || album != nil || contentKey != nil else {
            return nil
        }
        let position = position.flatMap { $0.isFinite && $0 >= 0 && $0 <= (duration ?? .infinity) ? $0 : nil }
        self.title = title
        self.artist = artist
        self.album = album
        self.contentKey = contentKey
        self.duration = duration
        self.position = position
        self.positionUpdatedAtUnix = position == nil ? nil : positionUpdatedAtUnix.flatMap { $0.isFinite ? $0 : nil }
        self.artwork = artwork
    }

    /// A digest of the identifying fields present in this report, so a prepared cover can be tied to the
    /// track it was prepared for (`RemoteMediaArtworkSource`). It is not a canonical track id: the same
    /// media reported with different fields gets a different value.
    var cacheIdentity: RemoteMediaDigest {
        RemoteMediaDigest(hashingFields: [title, artist, album, contentKey?.hexString])
    }

    /// This track with a different cover. Nothing else about it can have become invalid.
    func with(artwork: RemoteMediaArtwork) -> RemoteMediaTrack {
        RemoteMediaTrack(
            title: title,
            artist: artist,
            album: album,
            contentKey: contentKey,
            duration: duration,
            position: position,
            positionUpdatedAtUnix: positionUpdatedAtUnix,
            artwork: artwork
        ) ?? self
    }
}
