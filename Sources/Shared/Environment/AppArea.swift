import Foundation
import GRDB
import HAKit

public struct AppArea: Codable, FetchableRecord, PersistableRecord {
    /// serverId-areaId
    public let id: String
    public let serverId: String
    public let areaId: String
    public let name: String
    public let aliases: [String]
    public let picture: String?
    public let icon: String?
    /// Array containing entity Ids that belog to area
    public let entities: Set<String>

    public init(
        id: String,
        serverId: String,
        areaId: String,
        name: String,
        aliases: [String],
        picture: String?,
        icon: String?,
        entities: Set<String>
    ) {
        self.id = id
        self.serverId = serverId
        self.areaId = areaId
        self.name = name
        self.aliases = aliases
        self.picture = picture
        self.icon = icon
        self.entities = entities
    }

    public init(from area: HAAreaResponse, serverId: String, entities: Set<String>?) {
        self.id = "\(serverId)-\(area.areaId)"
        self.serverId = serverId
        self.areaId = area.areaId
        self.name = area.name
        self.aliases = area.aliases
        self.picture = area.picture
        self.icon = area.icon
        self.entities = entities ?? []
    }
}

