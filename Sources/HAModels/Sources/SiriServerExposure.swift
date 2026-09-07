import Foundation
import GRDB

/// Whether one server's entities may be offered to Siri.
///
/// A row exists only once the user has changed the setting for that server: absent means exposed,
/// so a new server behaves the way every server did before this setting existed.
///
/// Pure, extension-safe model (Foundation + GRDB only); the `Current.database()`-backed queries
/// live in an extension in the `Shared` module.
public struct SiriServerExposure: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Sendable {
    public static let databaseTableName = GRDBDatabaseTable.siriServerExposure.rawValue

    /// The server this applies to. One row per server, so the id is the server's own identifier.
    public var serverId: String
    public var isExposed: Bool

    public var id: String { serverId }

    public init(serverId: String, isExposed: Bool) {
        self.serverId = serverId
        self.isExposed = isExposed
    }
}
