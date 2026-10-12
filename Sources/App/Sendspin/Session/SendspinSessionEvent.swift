import Foundation

/// What a session tells the player service about its server.
enum SendspinSessionEvent: Equatable {
    case connected(serverName: String)
    case groupUpdated(SendspinGroupUpdate)
    /// The track now playing, and its position in milliseconds at the moment of reporting.
    case metadata(SendspinMetadataState?, positionMs: Int64?)
    case controller(SendspinControllerState?)
    case streamStarted
    case streamEnded
    case volumeChanged(volume: Int, muted: Bool)
    case outputDelayChanged(milliseconds: Int)
    case paired(serverName: String)
    case unpaired
}
