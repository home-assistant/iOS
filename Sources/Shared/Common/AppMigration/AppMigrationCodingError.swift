import Foundation

/// Why a migration payload could not be produced or read.
public enum AppMigrationCodingError: LocalizedError {
    /// The blob is not decodable as a migration payload at all.
    case malformedPayload
    /// The blob decodes, but was written by something other than the migration exporter.
    case notAMigrationPayload
    /// The blob was written by a newer app than this one and cannot be read safely.
    case unsupportedSchema
    /// The payload needs more round trips between the apps than the flow is willing to make.
    case payloadTooLarge

    public var errorDescription: String? {
        switch self {
        case .malformedPayload:
            return L10n.AppMigration.Error.malformedPayload
        case .notAMigrationPayload:
            return L10n.AppMigration.Error.notAMigrationPayload
        case .unsupportedSchema:
            return L10n.AppMigration.Error.unsupportedSchema
        case .payloadTooLarge:
            return L10n.AppMigration.Error.payloadTooLarge
        }
    }
}
