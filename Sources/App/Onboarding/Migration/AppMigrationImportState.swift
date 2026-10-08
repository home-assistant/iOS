import Foundation

/// Where the new app is while it waits for, receives and applies the previous app's setup.
enum AppMigrationImportState: Equatable {
    /// The previous app has been asked to open; the user confirms it did, or asks again.
    case openingPreviousApp
    case receiving
    case applying
    case failed(message: String)
}
