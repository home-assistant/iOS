import Foundation

/// A decoded `metadata` state object. `timestamp` is a server-clock instant: it says when the
/// state takes effect and is the point progress extrapolates from.
struct SendspinTrackMetadata: Decodable, Equatable {
    struct Progress: Decodable, Equatable {
        let trackProgress: Int
        /// 0 means unknown or unlimited, as for live radio.
        let trackDuration: Int
        /// Multiplier x1000; 0 means paused.
        let playbackSpeed: Int

        enum CodingKeys: String, CodingKey {
            case trackProgress = "track_progress"
            case trackDuration = "track_duration"
            case playbackSpeed = "playback_speed"
        }
    }

    let timestamp: Int64
    let title: String?
    let artist: String?
    let albumArtist: String?
    let album: String?
    let artworkURL: String?
    let year: Int?
    let track: Int?
    let progress: Progress?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case title
        case artist
        case albumArtist = "album_artist"
        case album
        case artworkURL = "artwork_url"
        case year
        case track
        case progress
    }

    /// The position at `serverTime`, extrapolated from the last reported progress. Both times are
    /// in the server clock domain.
    func positionMilliseconds(atServerTime serverTime: Int64) -> Int? {
        guard let progress else { return nil }
        let elapsed = Double(serverTime - timestamp) * Double(progress.playbackSpeed) / 1_000_000
        let position = Double(progress.trackProgress) + elapsed
        if progress.trackDuration != 0 {
            return Int(max(min(position, Double(progress.trackDuration)), 0))
        }
        return Int(max(position, 0))
    }
}
