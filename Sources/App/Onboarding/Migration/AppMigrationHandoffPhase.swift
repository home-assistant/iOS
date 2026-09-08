import Foundation

/// Where the previous app stands once a transfer has been requested. While a phase is set the app
/// shows only the transfer screen and opens no connections, across relaunches.
enum AppMigrationHandoffPhase: Equatable {
    case requested(AppMigrationSession)
    case handedOff
}
