import Foundation
import Shared

/// What each side of the handoff narrates while it works. The work itself is near-instant, so both
/// sides pace themselves to this script and the user sees what is happening instead of a flash.
enum AppMigrationProgressScript {
    case export
    case `import`

    static let duration: TimeInterval = 8
    /// Once the ring is full a checkmark draws on and settles; neither side moves on before it has.
    static let completionDuration: TimeInterval = 1.6
    /// How long the previous app shows that it emptied itself before sending the user back.
    static let erasedReadDuration: TimeInterval = 3
    static var totalDuration: TimeInterval { duration + completionDuration }

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
