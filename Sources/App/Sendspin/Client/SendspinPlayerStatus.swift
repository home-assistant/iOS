import Foundation

/// What the Sendspin player is doing, as the settings screen shows it.
enum SendspinPlayerStatus: Equatable {
    case off
    /// Enabled, browsing for servers, none connected yet.
    case searching
    case connecting(serverName: String)
    /// Connected and handshaken; `isReady` reports whether the clock has converged enough to play.
    case connected(serverName: String, trust: SendspinTrustLevel, isReady: Bool)
    case failed(String)
}
