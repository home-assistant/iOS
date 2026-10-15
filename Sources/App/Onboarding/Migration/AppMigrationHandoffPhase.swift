import Foundation

/// Where the previous app stands once a transfer has been requested. While a phase is set the app
/// shows only the transfer screen and opens no connections, across relaunches.
enum AppMigrationHandoffPhase: Equatable {
    /// `startedHere` is true when this app minted the session from its own announcement, so the key
    /// still has to reach the new app along with the payload.
    case requested(AppMigrationSession, startedHere: Bool)
    /// The payload has left; the session id is what a later restart or erase has to quote.
    case handedOff(sessionID: UUID)
    /// The new app asked this one to wipe itself after the transfer; nothing is left to show but the
    /// reminder to delete the app.
    case erased(sessionID: UUID)
}
