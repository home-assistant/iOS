import Foundation

/// What the followed player is doing, independent of how its integration spells it (an Echo answering
/// Pause can pass through `idle` on its way from `playing` to `paused`).
public enum RemoteMediaPlaybackState: Sendable {
    case playing
    case paused
    case buffering
    /// `idle`, `on`, `off` or `standby`: the player is reachable and not playing anything.
    case stopped
    /// `unavailable`, `unknown`, or a state this client does not recognize. It says nothing about whether
    /// playback stopped, so the reducer keeps the previous playback state; it cannot tell these apart.
    case indeterminate

    init(homeAssistantState state: String) {
        switch state {
        case "playing": self = .playing
        case "paused": self = .paused
        case "buffering": self = .buffering
        case "idle", "on", "off", "standby": self = .stopped
        default: self = .indeterminate
        }
    }
}
