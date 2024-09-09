import Foundation
import GRDB

public struct HAAppEntity: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    public let id: String
    public let entityId: String
    public let serverId: String
    public let domain: String
    public let name: String
    public let icon: String?

    public init(id: String, entityId: String, serverId: String, domain: String, name: String, icon: String?) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.domain = domain
        self.name = name
        self.icon = icon
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
