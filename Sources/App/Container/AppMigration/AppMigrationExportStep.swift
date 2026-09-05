import Foundation
import SFSafeSymbols
import Shared

/// The steps the app being replaced runs through while packaging its data, in order.
enum AppMigrationExportStep: String, AppMigrationStepDescribing {
    case servers
    case configuration
    case packaging
    case handoff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .servers: return L10n.AppMigration.Step.Export.servers
        case .configuration: return L10n.AppMigration.Step.Export.configuration
        case .packaging: return L10n.AppMigration.Step.Export.packaging
        case .handoff: return L10n.AppMigration.Step.Export.handoff
        }
    }

    var icon: SFSymbol {
        switch self {
        case .servers: return .serverRack
        case .configuration: return .gearshape
        case .packaging: return .shippingboxFill
        case .handoff: return .arrowRightCircleFill
        }
    }
}
