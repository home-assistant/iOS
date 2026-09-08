import Foundation
import Shared

/// What each side of the handoff narrates while it works. The work itself is near-instant, so both
/// sides pace themselves to this script and the user sees what is happening instead of a flash.
enum AppMigrationProgressScript {
    case export
    case `import`

    static let duration: TimeInterval = 8

    var stages: [String] {
        switch self {
        case .export: [
                L10n.AppMigration.Progress.Export.packaging,
                L10n.AppMigration.Progress.Export.copying,
                L10n.AppMigration.Progress.Export.handingOver,
            ]
        case .import: [
                L10n.AppMigration.Progress.Import.receiving,
                L10n.AppMigration.Progress.Import.restoring,
                L10n.AppMigration.Progress.Import.applying,
            ]
        }
    }
}
