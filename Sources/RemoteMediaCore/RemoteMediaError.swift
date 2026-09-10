import Foundation

public enum RemoteMediaError: Error {
    case invalidCommand
    /// The followed entity id is not one this feature may act on. See `RemoteMediaEntityId`.
    case invalidSelection
    case noLongerFollowing
    case unavailable
    case invalidArtwork
}
