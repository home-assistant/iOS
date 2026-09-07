import Foundation

/// Where the previous app is while it packages its setup and hands it to the new app.
enum AppMigrationExportState: Equatable {
    case idle
    case preparing
    case handedOff
    case failed(message: String)
}
