import Foundation

/// The `metadata` object of `server/state`.
struct SendspinMetadataState: Codable, Equatable {
    let timestamp: Int64
    let title: String?
    let artist: String?
    let albumArtist: String?
    let album: String?
    let artworkURL: String?
    let year: Int?
    let track: Int?
    let progress: SendspinTrackProgress?

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

    /// The playback position at a given server time, extrapolated from `timestamp` as the
    /// specification describes.
    func trackPosition(atServerTime serverTime: Int64) -> Int64? {
        guard let progress else { return nil }
        let elapsed = Double(serverTime - timestamp) * Double(progress.playbackSpeed) / 1_000_000
        let position = Int64((Double(progress.trackProgress) + elapsed).rounded())
        if progress.trackDuration != 0 {
            return max(min(position, progress.trackDuration), 0)
        }
        return max(position, 0)
    }
}
