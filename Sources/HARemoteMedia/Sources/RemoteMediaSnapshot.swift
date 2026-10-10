import Foundation

/// One followed `media_player` as Remote Now Playing shows it, and the part of its state that is safe to
/// publish outside the app: display strings the entity already publishes, `RemoteMediaDigest`s instead of
/// raw integration values, and a `RemoteMediaArtwork`.
///
/// It has no field for routing or authentication; whatever follows the player keeps those locally. An
/// entity id can appear only as `player.name`, the display fallback when there is no `friendly_name`.
public struct RemoteMediaSnapshot: Equatable, Sendable {
    public let player: RemoteMediaPlayer
    /// What is playing, or `nil` when the player reports nothing to show.
    public let track: RemoteMediaTrack?

    init(player: RemoteMediaPlayer, track: RemoteMediaTrack?) {
        self.player = player
        self.track = track
    }
}
