import Foundation
import GRDB
import HAKit

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

    public init(
        from area: HAAreasRegistryResponse,
        serverId: String,
        entities: Set<String>?,
        sortOrder: Int?,
        floorName: String? = nil
    ) {
        self.id = "\(serverId)-\(area.areaId)"
        self.serverId = serverId
        self.areaId = area.areaId
        self.name = area.name
        self.aliases = area.aliases
        self.picture = area.picture
        self.icon = area.icon
        self.sortOrder = sortOrder
        self.entities = entities ?? []
        self.floorId = area.floorId
        self.floorName = floorName
    }
}
