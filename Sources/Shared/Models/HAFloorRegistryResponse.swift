import Foundation
import HAKit

public struct HAFloorRegistryResponse: HADataDecodable {
    public let aliases: [String]
    public let floorId: String
    public let name: String
    public let level: Int?
    // e.g. "mdi:home-floor-1"
    public let icon: String?

    public init(data: HAData) throws {
        try self.init(
            aliases: data.decode("aliases"),
            floorId: data.decode("floor_id"),
            name: data.decode("name"),
            level: try? data.decode("level"),
            icon: try? data.decode("icon")
        )
    }

    public init(
        aliases: [String],
        floorId: String,
        name: String,
        level: Int? = nil,
        icon: String? = nil
    ) {
        self.aliases = aliases
        self.floorId = floorId
        self.name = name
        self.level = level
        self.icon = icon
    }
}
