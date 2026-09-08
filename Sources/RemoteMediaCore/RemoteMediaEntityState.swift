import Foundation

/// What one `media_player` entity says, split into the part that crosses into the extension and the
/// part that must not.
///
/// `entity_picture` carries a signed token, and `RemoteMediaSnapshot` is serialized through Apple's
/// RemoteMedia infrastructure, so the source path stays here in the host app and only a cache key
/// reaches the extension.
public struct RemoteMediaEntityState: Equatable, Sendable {
    public let snapshot: RemoteMediaSnapshot
    public let artworkSource: String?

    public init(snapshot: RemoteMediaSnapshot, artworkSource: String?) {
        self.snapshot = snapshot
        self.artworkSource = artworkSource
    }
}
