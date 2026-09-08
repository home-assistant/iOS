import Foundation

/// What the followed player is doing, independent of the exact string Home Assistant reported.
///
/// Integrations differ in how they spell a pause: an Echo can pass through `idle` on its way from
/// `playing` to `paused`. Collapsing them here keeps that variation out of the session lifecycle.
public enum RemoteMediaPlaybackState: String, Codable, Equatable, Sendable {
    case playing
    case paused
    case buffering
    case stopped
    /// `unavailable` or `unknown`: the integration is not reporting, which is not the same as
    /// having stopped.
    case indeterminate

    public init(homeAssistantState state: String) {
        switch state {
        case "playing": self = .playing
        case "paused": self = .paused
        case "buffering": self = .buffering
        case "idle", "off", "standby": self = .stopped
        default: self = .indeterminate
        }
    }

    /// Whether the Now Playing card should show this as actively playing.
    public var isPlaying: Bool {
        switch self {
        case .playing, .buffering: return true
        case .paused, .stopped, .indeterminate: return false
        }
    }
}
