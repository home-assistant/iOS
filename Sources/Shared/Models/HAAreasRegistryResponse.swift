import Foundation
import HAKit

public struct HAAreasRegistryResponse: HADataDecodable {
    public let aliases: [String]
    public let areaId: String
    public let name: String
    public let picture: String?
    // e.g. "mdi:sofa"
    public let icon: String?
    // Identifier of the floor this area belongs to, if any.
    public let floorId: String?
    public let temperatureEntityId: String?
    public let humidityEntityId: String?
    public init(data: HAData) throws {
        try self.init(
            aliases: data.decode("aliases"),
            areaId: data.decode("area_id"),
            name: data.decode("name"),
            picture: try? data.decode("picture"),
            icon: try? data.decode("icon"),
            floorId: try? data.decode("floor_id"),
            temperatureEntityId: try? data.decode("temperature_entity_id"),
            humidityEntityId: try? data.decode("humidity_entity_id")
        )
    }

    public init(
        aliases: [String],
        areaId: String,
        name: String,
        picture: String? = nil,
        icon: String? = nil,
        floorId: String? = nil,
        temperatureEntityId: String? = nil,
        humidityEntityId: String? = nil
    ) {
        self.aliases = aliases
        self.areaId = areaId
        self.name = name
        self.picture = picture
        self.icon = icon
        self.floorId = floorId
        self.temperatureEntityId = temperatureEntityId
        self.humidityEntityId = humidityEntityId
    }
}
