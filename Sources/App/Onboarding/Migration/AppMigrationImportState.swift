import Foundation

/// Where the new app is while it waits for, receives and applies the previous app's setup.
enum AppMigrationImportState: Equatable {
    /// The previous app has been asked to open; the user confirms it did, or asks again.
    case openingPreviousApp
    case receiving
    /// The payload has been opened and matched to the session, but this app already holds a setup the
    /// transfer would replace; nothing is touched until the user decides.
    case confirmingReplacement(existingServerNames: [String], incomingServerNames: [String])
    case applying
    case failed(message: String)

    var isConfirmingReplacement: Bool {
        if case .confirmingReplacement = self {
            return true
        }
        return false
    }
}
