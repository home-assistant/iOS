import Foundation

/// When a command's effect has actually landed in Home Assistant.
///
/// A `call_service` returning 200 only means Home Assistant accepted the call. Cloud-backed
/// integrations answer well after that, so each command gets the condition that describes its own
/// effect rather than one crude "something changed".
public enum RemoteMediaSettleCondition: Equatable, Sendable {
    /// Track identity moved on. Used by next and previous.
    case trackChanged(from: String)
    case playing
    case notPlaying
    case position(TimeInterval)
    case volume(Double)
    /// Playback has clearly stopped. Note this is `media_stop`, not stop following.
    case stopped

    /// Seek and volume compare against what the device reports, which is rounded and rescaled on
    /// the way through an integration, so neither can be matched exactly.
    static let positionTolerance: TimeInterval = 5
    static let volumeTolerance = 0.05

    public func isSettled(_ snapshot: RemoteMediaSnapshot) -> Bool {
        switch self {
        case let .trackChanged(previous):
            // Only a real track counts: an Echo blanks its metadata mid-change, and treating that
            // empty report as the new track would stop reconciliation one step early.
            return snapshot.hasMeaningfulMedia && snapshot.trackId != previous
        case .playing:
            return snapshot.playback.isPlaying
        case .notPlaying:
            // A transient `idle` on the way to `paused` counts: both are "not playing", and the
            // reducer keeps the media either way.
            return snapshot.playback == .paused || snapshot.playback == .stopped
        case let .position(target):
            guard let position = snapshot.position else { return false }
            return abs(position - target) <= Self.positionTolerance
        case let .volume(target):
            guard let volume = snapshot.volume else { return false }
            return abs(volume - target) <= Self.volumeTolerance
        case .stopped:
            return snapshot.playback == .stopped || snapshot.playback == .paused
        }
    }

    /// The condition a command should be reconciled against, given the state it started from.
    public static func forCommand(
        _ command: RemoteMediaCommand,
        value: Double?,
        previous: RemoteMediaSnapshot?
    ) -> RemoteMediaSettleCondition {
        switch command {
        case .next, .previous:
            return .trackChanged(from: previous?.trackId ?? "")
        case .play:
            return .playing
        case .pause:
            return .notPlaying
        case .togglePlayPause:
            return previous?.playback.isPlaying == true ? .notPlaying : .playing
        case .stop:
            return .stopped
        case .seek:
            return .position(value ?? 0)
        case .volume:
            return .volume(value ?? 0)
        }
    }
}
