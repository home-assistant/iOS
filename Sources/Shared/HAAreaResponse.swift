import Foundation
import HAKit

public struct HAAreaResponse: HADataDecodable {
    public let aliases: [String]
    public let areaId: String
    public let name: String
    public let picture: String?
    // e.g. "mdi:sofa"
    public let icon: String?

    public init(data: HAData) throws {
        try self.init(
            aliases: data.decode("aliases"),
            areaId: data.decode("area_id"),
            name: data.decode("name"),
            picture: try? data.decode("picture"),
            icon: try? data.decode("icon")
        )
    }

    public init(
        aliases: [String],
        areaId: String,
        name: String,
        picture: String? = nil,
        icon: String? = nil
    ) {
        self.aliases = aliases
        self.areaId = areaId
        self.name = name
        self.picture = picture
        self.icon = icon
    }
}

public struct HAEntityAreaResponse: HADataDecodable {
    public let areaId: String?
    public let entityId: String?
    public let deviceId: String?

    public init(data: HAData) throws {
        self.init(
            areaId: try? data.decode("area_id"),
            entityId: try? data.decode("entity_id"),
            deviceId: try? data.decode("device_id")
        )
    }

    public init(areaId: String?, entityId: String?, deviceId: String?) {
        self.areaId = areaId
        self.entityId = entityId
        self.deviceId = deviceId
    }
}

public struct HADeviceAreaResponse: HADataDecodable {
    public let areaId: String?
    public let deviceId: String?

    public init(data: HAData) throws {
        self.init(
            areaId: try? data.decode("area_id"),
            deviceId: try? data.decode("id")
        )
    }

    public init(areaId: String?, deviceId: String?) {
        self.areaId = areaId
        self.deviceId = deviceId
    }
}
