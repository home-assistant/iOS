import Foundation
import GRDB

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
///
/// The `DeviceClass` helper and the `Current.database()`-backed queries live in extensions in the
/// `Shared` module.
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

    public enum ConfigInclude {
        case all
        case hidden
        /// Kept for source compatibility. Disabled entities are no longer stored (the entity
        /// registry is sourced from `list_for_display`, which omits them), so this has no effect.
        case disabled
    }
}

public enum ServerEntity {
    public static func uniqueId(serverId: String, entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }
}
