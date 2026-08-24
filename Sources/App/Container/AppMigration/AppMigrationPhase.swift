import Foundation

/// Where the user is inside the migration flow on the app being replaced.
enum AppMigrationPhase: Equatable {
    /// Explaining what is about to move, waiting for the user to start.
    case intro
    /// Packaging the data, with the step list on screen.
    case packaging
    /// Packaged, but the new app is not installed yet.
    case needsDestinationApp
    /// The new app was opened with the payload; waiting for it to confirm the import.
    case awaitingConfirmation
    /// The new app confirmed. This app is retired.
    case completed(serverCount: Int)
    /// Packaging failed. Carries the message to show.
    case failed(message: String)
}
