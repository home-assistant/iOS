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
        rawDeviceClass: String?,
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.domain = domain
        self.name = name
        self.icon = icon
        self.rawDeviceClass = rawDeviceClass
    }

    public var deviceClass: DeviceClass {
        DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
    }

    public var isHidden: Bool {
        (
            try? AppEntityRegistry.config(serverId: serverId).first(where: { $0.entityId == entityId })?.hiddenBy != nil
        ) ??
            false
    }

    public var isDisabled: Bool {
        (
            try? AppEntityRegistry.config(serverId: serverId).first(where: { $0.entityId == entityId })?
                .disabledBy != nil
        ) ?? false
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

            let appEntityRegistry = try AppEntityRegistry.fetchAll(db)
            let allEntities = try HAAppEntity.fetchAll(db)

            // Build a dictionary for O(1) registry lookups keyed by "serverId-entityId"
            let registryDict = Dictionary(
                appEntityRegistry.compactMap { registry -> (String, AppEntityRegistry)? in
                    guard let entityId = registry.entityId else { return nil }
                    let key = "\(registry.serverId)-\(entityId)"
                    return (key, registry)
                },
                uniquingKeysWith: { first, _ in first }
            )

            let includeHidden = include.contains(.hidden)
            let includeDisabled = include.contains(.disabled)

            // Filter entities based on registry hiddenBy and disabledBy values
            return allEntities.filter { entity in
                let key = "\(entity.serverId)-\(entity.entityId)"
                guard let registry = registryDict[key] else {
                    // No registry entry found, include the entity
                    return true
                }

                let isHidden = registry.hiddenBy != nil
                let isDisabled = registry.disabledBy != nil

                // Exclude hidden entities unless includeHidden is set
                if isHidden, !includeHidden {
                    return false
                }

                // Exclude disabled entities unless includeDisabled is set
                if isDisabled, !includeDisabled {
                    return false
                }

                return true
            }
        })
    }

    public static func entity(id: String, serverId: String) -> HAAppEntity? {
        do {
            return try Current.database().read { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.entityId.rawValue) == id)
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                    .fetchOne(db)
            }
        } catch {
            Current.Log.error("Error fetching entity \(id) for server \(serverId): \(error)")
        }
        return nil
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
