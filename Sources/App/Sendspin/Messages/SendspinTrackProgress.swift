import Foundation

/// Playback position as of a metadata `timestamp`, which the client extrapolates from.
struct SendspinTrackProgress: Codable, Equatable {
    let trackProgress: Int64
    let trackDuration: Int64
    /// Speed multiplied by 1000: 1000 is normal speed, 0 is paused.
    let playbackSpeed: Int

    enum CodingKeys: String, CodingKey {
        case trackProgress = "track_progress"
        case trackDuration = "track_duration"
        case playbackSpeed = "playback_speed"
    }
}
