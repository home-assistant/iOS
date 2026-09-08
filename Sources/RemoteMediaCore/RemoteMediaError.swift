import Foundation

public enum RemoteMediaError: Error {
    case invalidCommand
    case noServer
    case noLongerFollowing
    case unavailable
    case invalidArtwork
    case timedOut
}
