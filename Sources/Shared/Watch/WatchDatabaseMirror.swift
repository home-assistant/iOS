import CryptoKit
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
    /// Blob identifier used when the phone proactively *pushes* the mirror to the watch over
    /// `transferFile` (background-capable), in addition to the watch-initiated chunked pull.
    public static let blobIdentifier = "watchDatabaseMirror.push"
    /// Key under which sync requests, sync-start replies and push metadata carry the per-table
    /// digest map used for delta syncs (see `tableDigests()`).
    public static let digestsKey = "digests"

    /// The reference tables. All optional with the same retain semantics as the complication
    /// fields below: `nil` means "this sync did not carry the table" — either a delta sync where
    /// the table was unchanged, or an older/partial payload — and the watch keeps its local rows.
    public var entities: [HAAppEntity]?
    public var areas: [AppArea]?
    public var pipelines: [AssistPipelines]?
    /// Legacy complications + modern configs so the watch reload routine is another chance to receive
    /// them (in addition to the background WatchConnectivity context push).
    ///
    /// Optional on purpose: `nil` means "this sync did not carry complication data" — an older build, a
    /// partial payload, or a decode/read failure — and the watch must RETAIN whatever it already has. A
    /// non-nil value (even an empty array) is authoritative and replaces the local rows, which is how a
    /// genuine "user deleted them all" propagates. This is what stops a half/broken sync from wiping the
    /// existing complications off the watch.
    public var complications: [WatchComplication]?
    public var complicationConfigs: [WatchComplicationConfig]?
    /// Registry rows for the entities used by complications, so the watch can format values with the
    /// right display precision without carrying the whole registry.
    public var complicationEntities: [EntityRegistryListForDisplay.Entity]
    /// The phone's servers (`ServerManager.restorableState()` encoding), so every sync — the chunked
    /// pull and the proactive background push — also refreshes the watch's servers *in addition to*
    /// the on-demand `serversConfigSync` interactive exchange (which additionally carries the mTLS
    /// client-certificate bundles; those Keychain materials stay off the mirror on purpose).
    /// Same contract as the complication fields: `nil` means "not carried", retain what's local.
    public var servers: Data?

    public init(
        entities: [HAAppEntity]?,
        areas: [AppArea]?,
        pipelines: [AssistPipelines]?,
        complications: [WatchComplication]? = nil,
        complicationConfigs: [WatchComplicationConfig]? = nil,
        complicationEntities: [EntityRegistryListForDisplay.Entity] = [],
        servers: Data? = nil
    ) {
        self.entities = entities
        self.areas = areas
        self.pipelines = pipelines
        self.complications = complications
        self.complicationConfigs = complicationConfigs
        self.complicationEntities = complicationEntities
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case entities, areas, pipelines, complications, complicationConfigs, complicationEntities, servers
    }

    // Decode the complication fields defensively: they were added after the mirror shipped, so a payload
    // from a different build (or any format drift) must not fail the whole mirror — that would also break
    // the watch home screen, which relies on the same sync. A missing key OR a decode failure yields
    // `nil` (retain existing rows); only a value that actually decodes is treated as authoritative.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The reference tables are optional for delta syncs: a missing key means "unchanged since
        // the digests the watch echoed" and the local rows are retained. Present-but-corrupt data
        // still throws — unlike the complication fields these are always encoded by builds that
        // send them at all.
        self.entities = try container.decodeIfPresent([HAAppEntity].self, forKey: .entities)
        self.areas = try container.decodeIfPresent([AppArea].self, forKey: .areas)
        self.pipelines = try container.decodeIfPresent([AssistPipelines].self, forKey: .pipelines)
        self.complications = (try? container.decodeIfPresent([WatchComplication].self, forKey: .complications))
            .flatMap { $0 }
        self.complicationConfigs = (try? container.decodeIfPresent(
            [WatchComplicationConfig].self,
            forKey: .complicationConfigs
        )).flatMap { $0 }
        self.complicationEntities = (try? container.decodeIfPresent(
            [EntityRegistryListForDisplay.Entity].self,
            forKey: .complicationEntities
        )).flatMap { $0 } ?? []
        self.servers = (try? container.decodeIfPresent(Data.self, forKey: .servers)).flatMap { $0 }
    }

    /// Domains the watch can add (mirrors the iPhone watch picker).
    private static var mirroredDomains: Set<String> {
        [Domain.script.rawValue, Domain.scene.rawValue, Domain.automation.rawValue]
    }

    /// Read the current reference tables from the local GRDB (called on the phone).
    public static func snapshot() throws -> WatchDatabaseMirror {
        // A read failure sends `nil` (not `[]`) so the watch retains its rows rather than being told the
        // phone has none — only a successful read is authoritative.
        let complications = try? WatchComplication.all()
        let configs = try? WatchComplicationConfig.all()
        // Precision lives in the entity registry; fetch just the entries the complications need.
        let entitiesByServer = Dictionary(grouping: (configs ?? []).compactMap { config -> (String, String)? in
            config.entityId.map { (config.serverId, $0) }
        }, by: { $0.0 })
        var registry: [EntityRegistryListForDisplay.Entity] = []
        for (serverId, pairs) in entitiesByServer {
            registry += (try? EntityRegistryListForDisplay.Entity.entries(
                serverId: serverId,
                entityIds: pairs.map(\.1)
            )) ?? []
        }
        // Resolved outside the GRDB read: servers live in their own store, not the database.
        let servers = Current.servers.restorableState()

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
                complicationEntities: registry,
                servers: servers
            )
        }
    }

    /// Overwrite the local GRDB reference tables with this snapshot (called on the watch). The watch
    /// only ever holds mirrored rows in these tables, so a full replace is correct. Complication
    /// registry rows are upserted (not wiped) so they don't disturb other registry data.
    public func apply() throws {
        try Current.database().write { db in
            // Every table follows the same rule: present (even empty) is authoritative and
            // replaces the local rows; absent means the sync didn't carry it — retain.
            if let entities {
                try HAAppEntity.deleteAll(db)
                for entity in entities {
                    try entity.insert(db)
                }
            }
            if let areas {
                try AppArea.deleteAll(db)
                for area in areas {
                    try area.insert(db)
                }
            }
            if let pipelines {
                try AssistPipelines.deleteAll(db)
                for pipeline in pipelines {
                    try pipeline.insert(db)
                }
            }
            // Only replace the complication tables when this sync actually carried them. A `nil` here is
            // a half/broken/older sync — keep the watch's existing complications instead of wiping them.
            if let complications {
                try WatchComplication.deleteAll(db)
                for complication in complications {
                    try complication.insert(db)
                }
            }
            if let complicationConfigs {
                try WatchComplicationConfig.deleteAll(db)
                for config in complicationConfigs {
                    try config.insert(db)
                }
            }
            // The registry is keyed on (serverId, entityId) with no stable primary key, so a plain
            // save() re-inserts on the next sync and violates that unique index (SQLite error 19).
            // Replace on conflict to upsert just these rows without wiping the rest of the registry.
            for entity in complicationEntities {
                try entity.insert(db, onConflict: .replace)
            }
        }
    }

    // MARK: - Delta sync digests

    /// Opaque per-table digests of this snapshot, generated and compared ONLY on the phone
    /// (property-list encoding isn't guaranteed byte-stable across devices, so the watch never
    /// computes these — it stores the map verbatim and echoes it on the next sync request).
    /// A group that is `nil` produces no digest, can never "match", and is always carried.
    public func tableDigests() -> [String: String] {
        let encoder = PropertyListEncoder()
        var digests: [String: String] = [:]
        if let entities, let data = try? encoder.encode(entities) {
            digests["entities"] = Self.digest(of: [data])
        }
        if let areas, let data = try? encoder.encode(areas) {
            digests["areas"] = Self.digest(of: [data])
        }
        if let pipelines, let data = try? encoder.encode(pipelines) {
            digests["pipelines"] = Self.digest(of: [data])
        }
        // The complication tables travel and change together; one digest covers all three.
        if let complications, let complicationConfigs,
           let complicationsData = try? encoder.encode(complications),
           let configsData = try? encoder.encode(complicationConfigs),
           let entitiesData = try? encoder.encode(complicationEntities) {
            digests["complications"] = Self.digest(of: [complicationsData, configsData, entitiesData])
        }
        if let servers {
            digests["servers"] = Self.digest(of: [servers])
        }
        return digests
    }

    private static func digest(of datas: [Data]) -> String {
        var hasher = SHA256()
        for data in datas {
            hasher.update(data: data)
        }
        return Data(hasher.finalize()).base64EncodedString()
    }

    /// A copy with every table whose digest positively matches the watch's stored digests omitted
    /// (`nil` = retain on the watch). Groups without a digest on either side are always carried.
    public func omittingTables(
        matching storedDigests: [String: String],
        currentDigests: [String: String]
    ) -> WatchDatabaseMirror {
        func matches(_ key: String) -> Bool {
            guard let current = currentDigests[key], let stored = storedDigests[key] else { return false }
            return current == stored
        }
        var copy = self
        if matches("entities") { copy.entities = nil }
        if matches("areas") { copy.areas = nil }
        if matches("pipelines") { copy.pipelines = nil }
        if matches("complications") {
            copy.complications = nil
            copy.complicationConfigs = nil
            copy.complicationEntities = []
        }
        if matches("servers") { copy.servers = nil }
        return copy
    }
}
