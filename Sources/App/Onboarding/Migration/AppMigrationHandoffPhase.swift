import Foundation

/// Where the previous app stands once a transfer has been requested. While a phase is set the app
/// shows only the transfer screen and opens no connections, across relaunches.
enum AppMigrationHandoffPhase: Equatable {
    /// `startedHere` is true when this app minted the session from its own announcement, so the key
    /// still has to reach the new app along with the payload.
    case requested(AppMigrationSession, startedHere: Bool)
    case handedOff
}
