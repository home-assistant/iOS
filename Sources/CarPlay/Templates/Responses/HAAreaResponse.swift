import Foundation
import HAKit

struct HAAreaResponse: HADataDecodable {
    let aliases: [String]
    let areaId: String
    let name: String
    let picture: String?

    init(data: HAData) throws {
        try self.init(
            aliases: data.decode("aliases"),
            areaId: data.decode("area_id"),
            name: data.decode("name"),
            picture: try? data.decode("picture")
        )
    }

    init(aliases: [String], areaId: String, name: String, picture: String? = nil) {
        self.aliases = aliases
        self.areaId = areaId
        self.name = name
        self.picture = picture
    }
}

struct HAEntityAreaResponse: HADataDecodable {
    let areaId: String?
    let entityId: String?
    let deviceId: String?

    init(data: HAData) throws {
        self.init(
            areaId: try? data.decode("area_id"),
            entityId: try? data.decode("entity_id"),
            deviceId: try? data.decode("device_id")
        )
    }

    init(areaId: String?, entityId: String?, deviceId: String?) {
        self.areaId = areaId
        self.entityId = entityId
        self.deviceId = deviceId
    }
}

struct HADeviceAreaResponse: HADataDecodable {
    let areaId: String?
    let deviceId: String?

    init(data: HAData) throws {
        self.init(
            areaId: try? data.decode("area_id"),
            deviceId: try? data.decode("id")
        )
    }

    init(areaId: String?, deviceId: String?) {
        self.areaId = areaId
        self.deviceId = deviceId
    }
}
