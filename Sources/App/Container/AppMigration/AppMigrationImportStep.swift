import Foundation
import SFSafeSymbols
import Shared

/// The steps the app taking over runs through while applying a payload, in order.
enum AppMigrationImportStep: String, AppMigrationStepDescribing {
    case reading
    case servers
    case configuration
    case finishing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: return L10n.AppMigration.Step.Import.reading
        case .servers: return L10n.AppMigration.Step.Import.servers
        case .configuration: return L10n.AppMigration.Step.Import.configuration
        case .finishing: return L10n.AppMigration.Step.Import.finishing
        }
    }

    var icon: SFSymbol {
        switch self {
        case .reading: return .docTextMagnifyingglass
        case .servers: return .serverRack
        case .configuration: return .gearshape
        case .finishing: return .sparkles
        }
    }
}
