import Foundation

/// What the player is doing, as the settings screen shows it.
enum SendspinPlayerStatus: Equatable {
    case stopped
    case awayFromHomeNetwork
    case starting
    /// Advertised and waiting for Music Assistant to connect.
    case listening(port: UInt16)
    case connected(serverName: String)
    case playing(serverName: String)
    /// Carries the reason so a taken port or a refused local-network permission shows in the app.
    case failed(message: String)
}
