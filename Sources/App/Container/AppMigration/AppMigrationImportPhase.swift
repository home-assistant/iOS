import Foundation

/// Where the app taking over is inside an incoming migration.
enum AppMigrationImportPhase: Equatable {
    case running
    case completed(AppMigrationImportSummary)
    case failed(message: String)
}
