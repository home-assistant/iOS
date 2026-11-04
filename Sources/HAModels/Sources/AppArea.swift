import Foundation
import GRDB

/// An area from Home Assistant, denormalized for rendering. The initializer that maps the
/// `HAAreasRegistryResponse` websocket payload lives in an extension in the `Shared` module.
public struct AppArea: Codable, FetchableRecord, PersistableRecord, Equatable {
    /// serverId-areaId
    public let id: String
    public let serverId: String
    public let areaId: String
    public let name: String
    public let aliases: [String]
    public let picture: String?
    public let icon: String?
    public let sortOrder: Int?
    /// Array containing entity Ids that belong to area
    public let entities: Set<String>
    /// Identifier of the floor this area belongs to, if any.
    public let floorId: String?
    /// Resolved display name of the floor this area belongs to, denormalized for rendering.
    public let floorName: String?

    public init(
        id: String,
        serverId: String,
        areaId: String,
        name: String,
        aliases: [String],
        picture: String?,
        icon: String?,
        sortOrder: Int?,
        entities: Set<String>,
        floorId: String? = nil,
        floorName: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.areaId = areaId
        self.name = name
        self.aliases = aliases
        self.picture = picture
        self.icon = icon
        self.sortOrder = sortOrder
        self.entities = entities
        self.floorId = floorId
        self.floorName = floorName
    }
}
