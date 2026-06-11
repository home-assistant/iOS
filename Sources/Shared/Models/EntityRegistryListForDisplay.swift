import Foundation
import GRDB
import HAKit

public struct EntityRegistryListForDisplay: HADataDecodable {
    public let entityCategories: [String: String]
    public let entities: [Entity]

    public init(data: HAData) throws {
        self.entityCategories = try data.decode("entity_categories")
        self.entities = try data.decode("entities")
    }

    /// A single entity returned by `config/entity_registry/list_for_display`.
    ///
    /// This is the app's entity registry model. It is decoded from the WebSocket payload
    /// (`HADataDecodable`) and persisted to GRDB (`FetchableRecord`/`PersistableRecord`); it
    /// replaces the former full `config/entity_registry/list` response, which carried nothing the
    /// app reads that isn't here, and lacked `dp` (decimalPlaces). Disabled entities are omitted by
    /// the server (they have no state to display).
    ///
    /// Home Assistant abbreviates the keys to keep the payload small; all of them are persisted so
    /// future features can use them without re-fetching. `Equatable` so the database updater can skip
    /// a no-op delete+reinsert when the fetched data matches what's stored.
    public struct Entity: HADataDecodable, Codable, FetchableRecord, PersistableRecord, Equatable {
        public static let databaseTableName = GRDBDatabaseTable.displayEntityRegistry.rawValue

        /// Owning server id. Absent from the WebSocket payload — assigned before persistence.
        public var serverId: String = ""

        public let entityId: String // ei
        public let platform: String? // pl
        public let labels: [String]? // lb
        public let deviceId: String? // di
        /// Effective display name (the user's custom name when set, otherwise the original name).
        public let name: String? // en
        public let hasEntityName: Bool? // hn
        /// Index into `EntityRegistryListForDisplay.entityCategories` (e.g. config / diagnostic).
        public let entityCategory: Int? // ec
        public let translationKey: String? // tk
        /// Effective display precision computed by Home Assistant; not present in the full registry.
        public let decimalPlaces: Int? // dp
        /// Explicit area override; when nil the entity inherits its device's area.
        public let areaId: String? // ai
        public let hidden: Bool? // hb
        public let icon: String? // ic

        public init(data: HAData) throws {
            self.entityId = try data.decode("ei")
            self.platform = try? data.decode("pl")
            self.labels = try? data.decode("lb")
            self.deviceId = try? data.decode("di")
            self.name = try? data.decode("en")
            self.hasEntityName = try? data.decode("hn")
            self.entityCategory = try? data.decode("ec")
            self.translationKey = try? data.decode("tk")
            self.decimalPlaces = try? data.decode("dp")
            self.areaId = try? data.decode("ai")
            self.hidden = try? data.decode("hb")
            self.icon = try? data.decode("ic")
        }

        public var isHidden: Bool { hidden == true }

        /// All persisted entities for a server.
        public static func config(serverId: String) throws -> [Entity] {
            try Current.database().read { db in
                try Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }
        }

        #if DEBUG
        // Test-only memberwise initializer
        public init(
            serverId: String = "",
            entityId: String,
            platform: String? = nil,
            labels: [String]? = nil,
            deviceId: String? = nil,
            name: String? = nil,
            hasEntityName: Bool? = nil,
            entityCategory: Int? = nil,
            translationKey: String? = nil,
            decimalPlaces: Int? = nil,
            areaId: String? = nil,
            hidden: Bool? = nil,
            icon: String? = nil
        ) {
            self.serverId = serverId
            self.entityId = entityId
            self.platform = platform
            self.labels = labels
            self.deviceId = deviceId
            self.name = name
            self.hasEntityName = hasEntityName
            self.entityCategory = entityCategory
            self.translationKey = translationKey
            self.decimalPlaces = decimalPlaces
            self.areaId = areaId
            self.hidden = hidden
            self.icon = icon
        }
        #endif
    }
}
