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
    public var hiddenBy: String?

    public init(
        id: String,
        entityId: String,
        serverId: String,
        domain: String,
        name: String,
        icon: String?,
        rawDeviceClass: String?,
        hiddenBy: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.domain = domain
        self.name = name
        self.icon = icon
        self.rawDeviceClass = rawDeviceClass
        self.hiddenBy = hiddenBy
    }

    public var deviceClass: DeviceClass {
        DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
    }

    public var isHidden: Bool {
        hiddenBy != nil
    }

    public static func config(includeHiddenEntities: Bool = false) throws -> [HAAppEntity]? {
        try Current.database().read({ db in
            if includeHiddenEntities {
                try HAAppEntity.fetchAll(db)
            } else {
                try HAAppEntity.filter(Column(DatabaseTables.AppEntity.hiddenBy.rawValue) == nil).fetchAll(db)
            }
        })
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
