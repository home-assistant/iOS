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
    public var disabledBy: String?

    public init(
        id: String,
        entityId: String,
        serverId: String,
        domain: String,
        name: String,
        icon: String?,
        rawDeviceClass: String?,
        hiddenBy: String? = nil,
        disabledBy: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.domain = domain
        self.name = name
        self.icon = icon
        self.rawDeviceClass = rawDeviceClass
        self.hiddenBy = hiddenBy
        self.disabledBy = disabledBy
    }

    public var deviceClass: DeviceClass {
        DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
    }

    public var isHidden: Bool {
        hiddenBy != nil
    }

    public var isDisabled: Bool {
        disabledBy != nil
    }

    public enum ConfigInclude {
        case all
        case hidden
        case disabled
    }

    /// Fetches app entities based on configuration filters.
    /// - Parameter include: Filter options - use `.all` to include everything, or combine `.hidden` and `.disabled` to
    /// include specific types
    /// - Returns: Array of filtered entities
    public static func config(include: [ConfigInclude] = []) throws -> [HAAppEntity] {
        try Current.database().read({ db in
            // If .all is specified, return everything
            if include.contains(.all) {
                return try HAAppEntity.fetchAll(db)
            }

            // Build query based on what should be included
            var query = HAAppEntity.all()

            let includeHidden = include.contains(.hidden)
            let includeDisabled = include.contains(.disabled)

            // If neither hidden nor disabled are explicitly included, filter them out
            if !includeHidden {
                query = query.filter(Column(DatabaseTables.AppEntity.hiddenBy.rawValue) == nil)
            }
            if !includeDisabled {
                query = query.filter(Column(DatabaseTables.AppEntity.disabledBy.rawValue) == nil)
            }

            return try query.fetchAll(db)
        })
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
