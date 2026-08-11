import Foundation
import GRDB
import HAKit

// `HAAppEntity` itself lives in the `HAModels` package; these are its `DeviceClass` helper and
// database-backed queries.
public extension HAAppEntity {
    var deviceClass: DeviceClass {
        DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
    }

    /// Fetches app entities based on configuration filters.
    /// - Parameter include: Filter options - use `.all` to include everything, or combine `.hidden` and `.disabled` to
    /// include specific types
    /// - Returns: Array of filtered entities
    static func config(include: [ConfigInclude] = []) throws -> [HAAppEntity] {
        try Current.database().read({ db in
            // If .all is specified, return everything
            if include.contains(.all) {
                return try HAAppEntity.fetchAll(db)
            }

            let registryEntities = try EntityRegistryListForDisplay.Entity.fetchAll(db)
            let allEntities = try HAAppEntity.fetchAll(db)

            // Build a dictionary for O(1) registry lookups keyed by "serverId-entityId"
            let registryDict = Dictionary(
                registryEntities.map { registry in
                    ("\(registry.serverId)-\(registry.entityId)", registry)
                },
                uniquingKeysWith: { first, _ in first }
            )

            let includeHidden = include.contains(.hidden)

            // Filter out hidden entities. Disabled entities are already absent from the registry
            // (list_for_display omits them), so no separate disabled filter is needed.
            return allEntities.filter { entity in
                let key = "\(entity.serverId)-\(entity.entityId)"
                guard let registry = registryDict[key] else {
                    // No registry entry found, include the entity
                    return true
                }

                // Exclude hidden entities unless includeHidden is set
                if registry.isHidden, !includeHidden {
                    return false
                }

                return true
            }
        })
    }

    /// Whether the watch area screens can render this entity, given the precomputed set of
    /// watch-addable domain raw values: a watch-addable domain, no config/diagnostic category, and
    /// not hidden in the entity registry (both baked into the row at write time; see
    /// `AppEntitiesModel`). Every watch area path must use this same predicate so browsing, the
    /// home-screen mode and the empty-area checks all agree.
    func isWatchAreaCompatible(allowedDomains: Set<String>) -> Bool {
        allowedDomains.contains(domain) && entityCategory == nil && isHidden != true
    }

    /// Entity ids the watch area screens can render for a server: watch-addable domains, without
    /// config/diagnostic or hidden entities. Used to drop areas that would show an empty screen.
    static func watchAreaEntityIds(serverId: String) throws -> Set<String> {
        let allowedDomains = Set(Domain.watchAddable.map(\.rawValue))
        let entities = try Current.database().read { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        let compatible = entities.filter { $0.isWatchAreaCompatible(allowedDomains: allowedDomains) }
        return Set(compatible.map(\.entityId))
    }

    static func entity(id: String, serverId: String) -> HAAppEntity? {
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
