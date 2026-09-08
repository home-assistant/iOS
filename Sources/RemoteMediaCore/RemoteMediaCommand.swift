import Foundation

public enum RemoteMediaCommand: String, CaseIterable, Sendable {
    case play, pause, togglePlayPause, stop, previous, next, seek, volume

    /// The `media_player` service this control calls. The payload is built by
    /// `RemoteMediaServiceCall`, which is what the webhook client sends.
    public var service: String {
        switch self {
        case .play: return "media_play"
        case .pause: return "media_pause"
        case .togglePlayPause: return "media_play_pause"
        case .stop: return "media_stop"
        case .previous: return "media_previous_track"
        case .next: return "media_next_track"
        case .seek: return "media_seek"
        case .volume: return "volume_set"
        }
    }
}
