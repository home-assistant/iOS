import Foundation
import GRDB
import HAKit

public struct HAAppEntity: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    public let id: String
    public let entityId: String
    public let serverId: String
    public let domain: String
    public let name: String
    public let icon: String?
    public let rawDeviceClass: String?

    public init(
        id: String,
        entityId: String,
        serverId: String,
        domain: String,
        name: String,
        icon: String?,
        rawDeviceClass: String?
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.domain = domain
        self.name = name
        self.icon = icon
        self.rawDeviceClass = rawDeviceClass
    }

    public var deviceClass: HAEntity.DeviceClass? {
        HAEntity.DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
    }

    public static func config() throws -> [HAAppEntity]? {
        try Current.database().read({ db in
            try HAAppEntity.fetchAll(db)
        })
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
