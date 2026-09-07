import Foundation
import Shared

enum AppMigrationError: LocalizedError {
    case declined
    case noPayload
    case wrongSession
    case invalidPayload
    case unsupportedVersion
    case previousAppUnavailable
    case newAppUnavailable

    var errorDescription: String? {
        switch self {
        case .declined: L10n.AppMigration.Error.declined
        case .noPayload: L10n.AppMigration.Error.noPayload
        case .wrongSession: L10n.AppMigration.Error.wrongSession
        case .invalidPayload: L10n.AppMigration.Error.invalidPayload
        case .unsupportedVersion: L10n.AppMigration.Error.unsupportedVersion
        case .previousAppUnavailable: L10n.AppMigration.Error.previousAppUnavailable
        case .newAppUnavailable: L10n.AppMigration.Error.newAppUnavailable
        }
    }
}
