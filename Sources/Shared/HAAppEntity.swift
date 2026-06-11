import Foundation
import GRDB
import HAKit

/// The entity "universe" cache, sourced from the REST `/states` endpoint (see `AppEntitiesModel`).
///
/// This is distinct from, and complementary to, `EntityRegistryListForDisplay.Entity` (the registry,
/// from `config/entity_registry/list_for_display`):
/// - `HAAppEntity` is every entity that currently has a state — including ones with no registry entry
///   (YAML/template/command-line entities, etc.) — and carries `domain` + `rawDeviceClass`, which the
///   registry does not. It's what pickers/widgets enumerate as "all selectable entities".
/// - The registry is config metadata (area, hidden, decimal precision, the user's name) for the
///   registered, non-disabled subset, and is only consulted to filter/enrich those entities.
///
/// `name` holds the **resolved display name**: the registry name (`list_for_display` `en`) when the
/// entity has a registry row, otherwise the live `friendly_name`, otherwise the `entityId`. It is
/// resolved once, at write time, by `AppEntitiesModel` (see `handle(appRelatedEntities:server:)`), so
/// readers can use `name` directly — there is no per-read registry lookup.
public struct HAAppEntity: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    public let id: String
    public let entityId: String
    public let serverId: String
    public let domain: String
    /// The entity's resolved **display name**, persisted in the database. `AppEntitiesModel` populates
    /// this at write time with the registry name (`list_for_display` `en`) when one exists, falling back
    /// to the live `friendly_name`, then the `entityId`. Readers should use this directly — it is already
    /// the name to show, so no per-read registry lookup is needed.
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

    public enum ConfigInclude {
        case all
        case hidden
        /// Kept for source compatibility. Disabled entities are no longer stored (the entity
        /// registry is sourced from `list_for_display`, which omits them), so this has no effect.
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
