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

    public struct Entity: HADataDecodable, Codable, FetchableRecord, PersistableRecord {
        public let entityId: String
        public let entityCategory: Int?
        public let decimalPlaces: Int?

        public init(data: HAData) throws {
            self.entityId = try data.decode("ei")
            self.entityCategory = try? data.decode("ec")
            self.decimalPlaces = try? data.decode("dp")
        }
    }
}

public struct AppEntityRegistryListForDisplay: Codable, FetchableRecord, PersistableRecord {
    /// serverId-entityId
    let id: String
    let serverId: String
    let entityId: String
    public let registry: EntityRegistryListForDisplay.Entity
}
