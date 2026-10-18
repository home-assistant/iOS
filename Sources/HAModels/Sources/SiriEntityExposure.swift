import Foundation
import GRDB

/// Whether one calendar or to-do list may be offered to Siri, and whether it is the one Siri falls
/// back to when the user does not name one.
///
/// A row exists only once the user has changed the setting for that entity: absent means exposed
/// and not the default, so every entity behaves the way it did before this setting existed.
///
/// Pure, extension-safe model (Foundation + GRDB only); the `Current.database()`-backed queries
/// live in an extension in the `Shared` module.
public struct SiriEntityExposure: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Sendable {
    public static let databaseTableName = GRDBDatabaseTable.siriEntityExposure.rawValue

    /// serverId-entityId
    public var id: String
    public var serverId: String
    public var entityId: String
    public var domain: String
    public var isExposed: Bool
    public var isDefault: Bool

    public init(serverId: String, entityId: String, domain: String, isExposed: Bool, isDefault: Bool) {
        self.id = ServerEntity.uniqueId(serverId: serverId, entityId: entityId)
        self.serverId = serverId
        self.entityId = entityId
        self.domain = domain
        self.isExposed = isExposed
        self.isDefault = isDefault
    }
}
