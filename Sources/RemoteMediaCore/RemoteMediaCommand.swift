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

    /// `value` as this command will actually be sent, clamped to the range the service accepts.
    ///
    /// One definition because two consumers have to agree on it: `RemoteMediaServiceCall` sends
    /// the clamped value, and `RemoteMediaSettleCondition` waits for the player to report it. When
    /// only the first clamped, an out-of-range request could never settle, and the read-back
    /// ladder spent all four of its attempts confirming a value nobody had asked for.
    public func clamped(_ value: Double) -> Double {
        switch self {
        case .seek: return max(0, value)
        case .volume: return min(1, max(0, value))
        case .play, .pause, .togglePlayPause, .stop, .previous, .next: return value
        }
    }
}
