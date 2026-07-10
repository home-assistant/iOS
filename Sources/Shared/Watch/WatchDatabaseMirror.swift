import Foundation
import GRDB

/// A snapshot of the phone's reference GRDB tables that the watch needs to configure itself offline.
///
/// The watch can't fetch from Home Assistant directly (no WebSockets on watchOS), so on each reload
/// the phone sends this snapshot and the watch writes it into its own GRDB. `MagicItemProvider` then
/// runs locally on the watch to list addable items, resolve names/icons and the area context — all
/// without the phone nearby.
///
/// Only what the add flow needs is included: scripts/scenes/automations (stored as entities), areas
/// (for the context line), and Assist pipelines. Device / entity-registry tables are intentionally
/// omitted — they're large and device context is rarely set for scripts/scenes. Even so, this snapshot
/// can exceed WatchConnectivity's per-message limit, so it is streamed as chunked guaranteed messages.
public struct WatchDatabaseMirror: WatchCodable {
    public var entities: [HAAppEntity]
    public var areas: [AppArea]
    public var pipelines: [AssistPipelines]
    /// Legacy complications + modern configs so the watch reload routine is another chance to receive
    /// them (in addition to the background WatchConnectivity context push).
    public var complications: [WatchComplication]
    public var complicationConfigs: [WatchComplicationConfig]
    /// Registry rows for the entities used by complications, so the watch can format values with the
    /// right display precision without carrying the whole registry.
    public var complicationEntities: [EntityRegistryListForDisplay.Entity]

    public init(
        entities: [HAAppEntity],
        areas: [AppArea],
        pipelines: [AssistPipelines],
        complications: [WatchComplication] = [],
        complicationConfigs: [WatchComplicationConfig] = [],
        complicationEntities: [EntityRegistryListForDisplay.Entity] = []
    ) {
        self.entities = entities
        self.areas = areas
        self.pipelines = pipelines
        self.complications = complications
        self.complicationConfigs = complicationConfigs
        self.complicationEntities = complicationEntities
    }

    private enum CodingKeys: String, CodingKey {
        case entities, areas, pipelines, complications, complicationConfigs, complicationEntities
    }

    // Decode the complication fields defensively: they were added after the mirror shipped, so a payload
    // from a different build (or any format drift) must not fail the whole mirror — that would also break
    // the watch home screen, which relies on the same sync.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entities = try container.decode([HAAppEntity].self, forKey: .entities)
        self.areas = try container.decode([AppArea].self, forKey: .areas)
        self.pipelines = try container.decode([AssistPipelines].self, forKey: .pipelines)
        self.complications = (try? container.decodeIfPresent([WatchComplication].self, forKey: .complications))
            .flatMap { $0 } ?? []
        self.complicationConfigs = (try? container.decodeIfPresent(
            [WatchComplicationConfig].self,
            forKey: .complicationConfigs
        )).flatMap { $0 } ?? []
        self.complicationEntities = (try? container.decodeIfPresent(
            [EntityRegistryListForDisplay.Entity].self,
            forKey: .complicationEntities
        )).flatMap { $0 } ?? []
    }

    /// Domains the watch can add (mirrors the iPhone watch picker).
    private static var mirroredDomains: Set<String> {
        [Domain.script.rawValue, Domain.scene.rawValue, Domain.automation.rawValue]
    }

    /// Read the current reference tables from the local GRDB (called on the phone).
    public static func snapshot() throws -> WatchDatabaseMirror {
        let complications = (try? WatchComplication.all()) ?? []
        let configs = (try? WatchComplicationConfig.all()) ?? []
        // Precision lives in the entity registry; fetch just the entries the complications need.
        let entitiesByServer = Dictionary(grouping: configs.compactMap { config -> (String, String)? in
            config.entityId.map { (config.serverId, $0) }
        }, by: { $0.0 })
        var registry: [EntityRegistryListForDisplay.Entity] = []
        for (serverId, pairs) in entitiesByServer {
            registry += (try? EntityRegistryListForDisplay.Entity.entries(
                serverId: serverId,
                entityIds: pairs.map(\.1)
            )) ?? []
        }

        return try Current.database().read { db in
            let entities = try HAAppEntity
                .filter(mirroredDomains.contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
                .fetchAll(db)
            let areas = try AppArea.fetchAll(db)
            let pipelines = try AssistPipelines.fetchAll(db)
            return WatchDatabaseMirror(
                entities: entities,
                areas: areas,
                pipelines: pipelines,
                complications: complications,
                complicationConfigs: configs,
                complicationEntities: registry
            )
        }
    }

    /// Overwrite the local GRDB reference tables with this snapshot (called on the watch). The watch
    /// only ever holds mirrored rows in these tables, so a full replace is correct. Complication
    /// registry rows are upserted (not wiped) so they don't disturb other registry data.
    public func apply() throws {
        try Current.database().write { db in
            try HAAppEntity.deleteAll(db)
            for entity in entities {
                try entity.insert(db)
            }
            try AppArea.deleteAll(db)
            for area in areas {
                try area.insert(db)
            }
            try AssistPipelines.deleteAll(db)
            for pipeline in pipelines {
                try pipeline.insert(db)
            }
            try WatchComplication.deleteAll(db)
            for complication in complications {
                try complication.insert(db)
            }
            try WatchComplicationConfig.deleteAll(db)
            for config in complicationConfigs {
                try config.insert(db)
            }
            // The registry is keyed on (serverId, entityId) with no stable primary key, so a plain
            // save() re-inserts on the next sync and violates that unique index (SQLite error 19).
            // Replace on conflict to upsert just these rows without wiping the rest of the registry.
            for entity in complicationEntities {
                try entity.insert(db, onConflict: .replace)
            }
        }
    }
}
