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

    /// Whether the watch may offer this entity in a list it generates itself, given the precomputed
    /// set of watch-addable domain raw values and the server's `watchExcludedEntityIds`.
    ///
    /// Excludes entities the user hid and config/diagnostic ones. This governs only the automatic
    /// lists — area browsing, the home-screen areas mode, the empty-area checks and the add flows —
    /// which is what "hidden" means in Home Assistant: it removes an entity from auto-generated
    /// views. An entity the user deliberately added to the watch home screen still renders; those
    /// items resolve through `MagicItemProvider` and never pass through this predicate.
    ///
    /// The row's own `isHidden`/`entityCategory` are checked too, but they are only refreshed when
    /// the phone rewrites its entity table, so `excludedEntityIds` — read live from the mirrored
    /// registry — is what makes the result correct on a server whose rows predate that write.
    func isWatchCompatible(allowedDomains: Set<String>, excludedEntityIds: Set<String> = []) -> Bool {
        allowedDomains.contains(domain)
            && entityCategory == nil
            && isHidden != true
            && !excludedEntityIds.contains(entityId)
    }

    /// Entity ids a server's registry marks as hidden or as config/diagnostic.
    ///
    /// `HAAppEntity` carries both facts as columns baked in at write time, but a server whose
    /// entities have not been rewritten since those columns shipped still stores `nil` for them,
    /// and the watch would then offer entities the user hid. The full registry is mirrored to the
    /// watch, so reading it directly makes the filter correct immediately rather than after the
    /// phone's next entity write.
    static func watchExcludedEntityIds(serverId: String) -> Set<String> {
        let ids = try? Current.database().read { db in
            try EntityRegistryListForDisplay.Entity
                .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                .filter(
                    Column(DatabaseTables.DisplayEntityRegistry.hidden.rawValue) == true
                        || Column(DatabaseTables.DisplayEntityRegistry.entityCategory.rawValue) != nil
                )
                .fetchAll(db)
                .map(\.entityId)
        }
        return Set(ids ?? [])
    }

    /// Entity ids the watch area screens can render for a server: watch-addable domains, without
    /// config/diagnostic or hidden entities. Used to drop areas that would show an empty screen.
    static func watchAreaEntityIds(serverId: String) throws -> Set<String> {
        let allowedDomains = Set(Domain.watchAddable.map(\.rawValue))
        let excluded = watchExcludedEntityIds(serverId: serverId)
        let entities = try Current.database().read { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        let compatible = entities
            .filter { $0.isWatchCompatible(allowedDomains: allowedDomains, excludedEntityIds: excluded) }
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
