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

    public init(
        entities: [HAAppEntity],
        areas: [AppArea],
        pipelines: [AssistPipelines]
    ) {
        self.entities = entities
        self.areas = areas
        self.pipelines = pipelines
    }

    /// Domains the watch can add (mirrors the iPhone watch picker).
    private static var mirroredDomains: Set<String> {
        [Domain.script.rawValue, Domain.scene.rawValue, Domain.automation.rawValue]
    }

    /// Read the current reference tables from the local GRDB (called on the phone).
    public static func snapshot() throws -> WatchDatabaseMirror {
        try Current.database().read { db in
            let entities = try HAAppEntity
                .filter(mirroredDomains.contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
                .fetchAll(db)
            let areas = try AppArea.fetchAll(db)
            let pipelines = try AssistPipelines.fetchAll(db)
            return WatchDatabaseMirror(entities: entities, areas: areas, pipelines: pipelines)
        }
    }

    /// Overwrite the local GRDB reference tables with this snapshot (called on the watch). The watch
    /// only ever holds mirrored rows in these tables, so a full replace is correct.
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
        }
    }
}
