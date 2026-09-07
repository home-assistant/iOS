import Foundation

/// Where the new app is while it waits for, receives and applies the previous app's setup.
enum AppMigrationImportState: Equatable {
    case waitingForPreviousApp
    case receiving
    case applying
    case failed(message: String)
}
