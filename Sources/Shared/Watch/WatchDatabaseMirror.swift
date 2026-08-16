import CryptoKit
import Foundation
import GRDB

/// A snapshot of the phone's reference GRDB tables that the watch needs to configure itself offline.
///
/// The watch is fed entirely through this phone-relayed sync: real watches block
/// `URLSessionWebSocketTask` for ordinary apps (TN3135), so the watch can't fetch from Home
/// Assistant directly. Reference tables, complications, configs, and servers all travel on this
/// mirror.
///
/// The snapshot's fidelity depends on the mirror version the watch advertises on its sync request
/// (`versionKey`):
/// - **Legacy (v1)**: only what the add flow needs — entities of watch-supported domains minus the
///   registry-hidden ones, areas (for the context line), and Assist pipelines. Device /
///   entity-registry tables are omitted. Served to watches that don't advertise a version.
/// - **Full reference (v2, `fullReferenceVersion`)**: every row of the server-reference tables the
///   iPhone maintains — entities (all domains, hidden included), the full entity registry, the full
///   device registry, areas and pipelines — so watch features can query the same data the same way
///   iPhone features do, and new registry-derived behavior needs no per-field mirroring work.
///   v2 payloads travel LZFSE-compressed (flagged via `compressedKey`) to offset the extra rows.
///
/// Either way the snapshot can exceed WatchConnectivity's per-message limit, so it is streamed as
/// chunked guaranteed messages (or pushed whole over `transferFile`).
public struct WatchDatabaseMirror: WatchCodable {
    /// Blob identifier used when the phone proactively *pushes* the mirror to the watch over
    /// `transferFile` (background-capable), in addition to the watch-initiated chunked pull.
    public static let blobIdentifier = "watchDatabaseMirror.push"
    /// Key under which sync requests, sync-start replies and push metadata carry the per-table
    /// digest map used for delta syncs (see `tableDigests()`).
    public static let digestsKey = "digests"
    /// Key under which the watch's sync request advertises the highest mirror version it
    /// understands. Absent means a legacy build → the phone serves the v1 snapshot.
    public static let versionKey = "mirrorVersion"
    /// Key flagging an LZFSE-compressed payload: set in the sync-start reply (the assembled chunks
    /// are compressed) and in push transfer metadata (the blob content is compressed). Absent means
    /// plain property-list bytes, so a legacy phone's reply is decoded unchanged.
    public static let compressedKey = "compressed"
    /// The mirror served to watches that don't advertise a version (see the type doc).
    public static let legacyVersion = 1
    /// The full-reference mirror (see the type doc).
    public static let fullReferenceVersion = 2

    /// The reference tables. All optional with the same retain semantics as the complication
    /// fields below: `nil` means "this sync did not carry the table" — either a delta sync where
    /// the table was unchanged, or an older/partial payload — and the watch keeps its local rows.
    public var entities: [HAAppEntity]?
    public var areas: [AppArea]?
    public var pipelines: [AssistPipelines]?
    /// The full entity registry (`list_for_display`), carried from `fullReferenceVersion` onwards so
    /// the watch holds the same registry the iPhone does. Same retain semantics as `entities`.
    /// Distinct from `registryEntities` below, the per-entity precision slice kept for legacy builds.
    public var registry: [EntityRegistryListForDisplay.Entity]?
    /// The full device registry, carried from `fullReferenceVersion` onwards. Same retain semantics.
    public var devices: [AppDeviceRegistry]?
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
    /// Registry rows for the entities the watch renders — complication entities plus the home-screen
    /// (magic item) entities — so the watch can format values with the right display precision
    /// without carrying the whole registry. Encoded under the pre-rename `complicationEntities` key
    /// so payloads stay compatible across builds.
    public var registryEntities: [EntityRegistryListForDisplay.Entity]
    /// The user's notification snooze presets, so the watch's long-look offers the same quick actions
    /// the iPhone does. The watch builds its actions from its *own* copy of this table at presentation
    /// time (`UNNotificationContent.userInfoActions`), so without this the watch was stuck forever on
    /// the 5/15/60 defaults its database seeds at creation.
    ///
    /// Unlike the reference tables above, an empty array is authoritative here: "the user disabled or
    /// deleted every preset" is a state worth propagating, and the phone only ever reads this table
    /// from its own settings (never from a server refresh that can transiently read back empty).
    /// `nil` still means "not carried" — a delta sync, or a payload from a build that predates this
    /// field — and the watch retains what it has.
    public var notificationSnoozeActions: [NotificationSnoozeAction]?
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
        registry: [EntityRegistryListForDisplay.Entity]? = nil,
        devices: [AppDeviceRegistry]? = nil,
        complications: [WatchComplication]? = nil,
        complicationConfigs: [WatchComplicationConfig]? = nil,
        registryEntities: [EntityRegistryListForDisplay.Entity] = [],
        notificationSnoozeActions: [NotificationSnoozeAction]? = nil,
        servers: Data? = nil
    ) {
        self.entities = entities
        self.areas = areas
        self.pipelines = pipelines
        self.registry = registry
        self.devices = devices
        self.complications = complications
        self.complicationConfigs = complicationConfigs
        self.registryEntities = registryEntities
        self.notificationSnoozeActions = notificationSnoozeActions
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case entities, areas, pipelines, registry, devices, complications, complicationConfigs, servers
        case notificationSnoozeActions
        case registryEntities = "complicationEntities"
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
        self.registry = try container.decodeIfPresent([EntityRegistryListForDisplay.Entity].self, forKey: .registry)
        self.devices = try container.decodeIfPresent([AppDeviceRegistry].self, forKey: .devices)
        self.complications = (try? container.decodeIfPresent([WatchComplication].self, forKey: .complications))
            .flatMap { $0 }
        self.complicationConfigs = (try? container.decodeIfPresent(
            [WatchComplicationConfig].self,
            forKey: .complicationConfigs
        )).flatMap { $0 }
        self.registryEntities = (try? container.decodeIfPresent(
            [EntityRegistryListForDisplay.Entity].self,
            forKey: .registryEntities
        )).flatMap { $0 } ?? []
        self.notificationSnoozeActions = (try? container.decodeIfPresent(
            [NotificationSnoozeAction].self,
            forKey: .notificationSnoozeActions
        )).flatMap { $0 }
        self.servers = (try? container.decodeIfPresent(Data.self, forKey: .servers)).flatMap { $0 }
    }

    /// Domains the legacy (v1) mirror carries (mirrors the iPhone watch picker), including the
    /// display-only sensor domains — the watch resolves their names and icons from these rows too.
    /// The full-reference (v2) mirror carries every domain instead.
    private static var mirroredDomains: Set<String> {
        Set(Domain.watchAddable.map(\.rawValue))
    }

    /// A reference table that reads back empty is carried as `nil` (retain) rather than as an
    /// authoritative empty array.
    ///
    /// The phone's tables are emptied and rewritten by `AppDatabaseUpdater`, and a read that lands
    /// on a transiently empty table (a refresh that fetched nothing, a reset, a wipe-and-rebuild in
    /// progress) would otherwise tell the watch "the phone genuinely has no entities" and delete
    /// every mirrored row — leaving the watch with a home screen that resolves nothing until the
    /// next successful sync. A server that legitimately has zero entities/areas is not a state
    /// worth propagating at the cost of that failure mode; the complication fields already follow
    /// the same "only a successful read is authoritative" rule.
    private static func retainingIfEmpty<T>(_ rows: [T]) -> [T]? {
        rows.isEmpty ? nil : rows
    }

    /// Digest keys for the tables this payload actually carries.
    ///
    /// The watch merges only these into its stored digest map, so a table the phone omitted — as a
    /// delta push, or because it read back empty — keeps its previous digest instead of adopting
    /// the phone's. That is what makes omission self-healing: if the phone's belief about what the
    /// watch holds is ever wrong, the watch still echoes its true digests on the next pull and the
    /// missing table is carried then.
    public var carriedDigestKeys: Set<String> {
        var keys: Set<String> = []
        if entities != nil { keys.insert("entities") }
        if areas != nil { keys.insert("areas") }
        if pipelines != nil { keys.insert("pipelines") }
        if registry != nil { keys.insert("registry") }
        if devices != nil { keys.insert("devices") }
        if complications != nil, complicationConfigs != nil { keys.insert("complications") }
        if notificationSnoozeActions != nil { keys.insert("notificationSnoozeActions") }
        if servers != nil { keys.insert("servers") }
        return keys
    }

    /// Digest keys whose mirrored table holds no rows in the local database (called on the watch).
    ///
    /// A stored digest asserts "this table is already here, at this version", and the phone uses that
    /// assertion to omit the table from the next sync. If the table is actually empty — wiped by an
    /// older build that accepted an authoritative empty payload, a failed apply, a "delete local
    /// data" — the assertion is false and the omission repeats on every sync, so the table never
    /// comes back. The visible symptom is a home screen that resolves no names and falls back to
    /// showing entity ids, alongside syncs that transfer almost nothing.
    ///
    /// Dropping these keys before echoing the digests makes the phone send those tables again, so a
    /// watch already stuck in that state repairs itself on its next sync.
    public static func digestKeysForEmptyLocalTables() -> Set<String> {
        (try? Current.database().read { db in
            var keys: Set<String> = []
            if try HAAppEntity.fetchCount(db) == 0 { keys.insert("entities") }
            if try AppArea.fetchCount(db) == 0 { keys.insert("areas") }
            if try AssistPipelines.fetchCount(db) == 0 { keys.insert("pipelines") }
            if try EntityRegistryListForDisplay.Entity.fetchCount(db) == 0 { keys.insert("registry") }
            if try AppDeviceRegistry.fetchCount(db) == 0 { keys.insert("devices") }
            return keys
        }) ?? []
    }

    /// All `.entity` items the watch home screen renders, including those nested inside folders.
    private static func entityItems(in items: [MagicItem]) -> [MagicItem] {
        items.flatMap { item -> [MagicItem] in
            switch item.type {
            case .entity:
                return [item]
            case .folder:
                return entityItems(in: item.items ?? [])
            default:
                return []
            }
        }
    }

    /// Read the current reference tables from the local GRDB (called on the phone). Pass the mirror
    /// version the receiving watch advertised; the default serves the legacy slice (see the type doc).
    public static func snapshot(version: Int = legacyVersion) throws -> WatchDatabaseMirror {
        // A read failure sends `nil` (not `[]`) so the watch retains its rows rather than being told the
        // phone has none — only a successful read is authoritative.
        let complications = try? WatchComplication.all()
        let configs = try? WatchComplicationConfig.all()
        // Precision lives in the entity registry; fetch just the entries the watch renders — the
        // complication entities plus the home-screen (magic item) entities.
        var entityIdsByServer: [String: Set<String>] = [:]
        for config in configs ?? [] {
            if let entityId = config.entityId {
                entityIdsByServer[config.serverId, default: []].insert(entityId)
            }
        }
        for item in entityItems(in: (try? WatchConfig.config())?.items ?? []) {
            entityIdsByServer[item.serverId, default: []].insert(item.id)
        }
        var registry: [EntityRegistryListForDisplay.Entity] = []
        for (serverId, entityIds) in entityIdsByServer {
            registry += (try? EntityRegistryListForDisplay.Entity.entries(
                serverId: serverId,
                entityIds: Array(entityIds)
            )) ?? []
        }
        // Deterministic order keeps the encoded payload — and therefore the delta-sync digests —
        // stable across snapshots of unchanged data.
        registry.sort { ($0.serverId, $0.entityId) < ($1.serverId, $1.entityId) }
        // Read in its own transaction (GRDB serializes reads, so this can't nest inside the one
        // below). Not run through `retainingIfEmpty` — these are the user's own settings, so "none
        // left" is a real choice that must reach the watch — but a *failed* read still carries `nil`,
        // keeping the "only a successful read is authoritative" rule the complication tables follow.
        let snoozeActions = try? Current.database().read { db in
            try NotificationSnoozeAction
                .order(Column(DatabaseTables.NotificationSnoozeAction.sortOrder.rawValue))
                .fetchAll(db)
        }
        // Resolved outside the GRDB read: servers live in their own store, not the database.
        let servers = Current.servers.restorableState()

        return try Current.database().read { db in
            let entities: [HAAppEntity]
            var fullRegistry: [EntityRegistryListForDisplay.Entity] = []
            var devices: [AppDeviceRegistry] = []
            if version >= fullReferenceVersion {
                // Full parity with the iPhone's reference tables: every row travels, including
                // hidden and config/diagnostic entities — the watch filters at read time exactly
                // like the iPhone does. Sorted so the encoded payload (and therefore the delta-sync
                // digests) stays stable across snapshots of unchanged data.
                entities = try HAAppEntity.fetchAll(db).sorted { $0.id < $1.id }
                fullRegistry = try EntityRegistryListForDisplay.Entity.fetchAll(db)
                    .sorted { ($0.serverId, $0.entityId) < ($1.serverId, $1.entityId) }
                devices = try AppDeviceRegistry.fetchAll(db).sorted { $0.id < $1.id }
            } else {
                // Legacy watches never receive the registry and their read paths predate the baked
                // `isHidden` flag, so they can't filter hidden entities themselves — exclude them
                // here, matching the iPhone entity picker.
                let hiddenKeys = try Set(
                    EntityRegistryListForDisplay.Entity.fetchAll(db)
                        .filter(\.isHidden)
                        .map { ServerEntity.uniqueId(serverId: $0.serverId, entityId: $0.entityId) }
                )
                entities = try HAAppEntity
                    .filter(mirroredDomains.contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
                    .fetchAll(db)
                    .filter {
                        !hiddenKeys.contains(ServerEntity.uniqueId(serverId: $0.serverId, entityId: $0.entityId))
                    }
            }
            let areas = try AppArea.fetchAll(db)
            let pipelines = try AssistPipelines.fetchAll(db)
            // Every reference table goes through `retainingIfEmpty`: an empty read is never sent as
            // an authoritative wipe (see its documentation).
            return WatchDatabaseMirror(
                entities: retainingIfEmpty(entities),
                areas: retainingIfEmpty(areas),
                pipelines: retainingIfEmpty(pipelines),
                registry: retainingIfEmpty(fullRegistry),
                devices: retainingIfEmpty(devices),
                complications: complications,
                complicationConfigs: configs,
                registryEntities: registry,
                notificationSnoozeActions: snoozeActions,
                servers: servers
            )
        }
    }

    // MARK: - Payload compression

    /// Compress an encoded mirror for transfer. Full-reference (v2) payloads always travel
    /// compressed — they carry every reference row — and the receiver knows via `compressedKey`,
    /// never by guessing.
    public static func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .lzfse) as Data
    }

    /// Inverse of `compress(_:)`, called by the watch before decoding a payload whose sync reply or
    /// push metadata carried the `compressedKey` flag.
    public static func decompress(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .lzfse) as Data
    }

    /// Overwrite the local GRDB reference tables with this snapshot (called on the watch). The watch
    /// only ever holds mirrored rows in these tables, so a full replace is correct. The legacy
    /// `registryEntities` precision slice is upserted (not wiped) so a v1 payload doesn't disturb
    /// registry rows a v2 sync delivered; a carried full `registry` replaces the table outright.
    public func apply() throws {
        try Current.database().write { db in
            try applyReferenceTables(in: db)
            try applyComplicationTables(in: db, includeRegistryRows: true)
        }
        logApplyOutcome()
    }

    /// Record which tables a payload actually carried and what the database holds afterwards.
    ///
    /// A byte count alone can't distinguish "carried every table" from "carried one table and
    /// retained the rest", and an apply that logs success can still leave a table empty — which is
    /// exactly the shape of the sync problems seen on device. Logging both ends of the operation
    /// makes a watch log enough on its own to tell which side lost the data.
    private func logApplyOutcome() {
        let carried = carriedDigestKeys.sorted().joined(separator: "+")
        let counts = (try? Current.database().read { db in
            try [
                "entities": HAAppEntity.fetchCount(db),
                "areas": AppArea.fetchCount(db),
                "registry": EntityRegistryListForDisplay.Entity.fetchCount(db),
                "devices": AppDeviceRegistry.fetchCount(db),
                "pipelines": AssistPipelines.fetchCount(db),
                "snoozeActions": NotificationSnoozeAction.fetchCount(db),
            ]
        }) ?? [:]
        let rows = counts.keys.sorted().map { "\($0)=\(counts[$0] ?? 0)" }.joined(separator: " ")
        Current.Log.info("Applied mirror carrying [\(carried.isEmpty ? "nothing" : carried)]; rows now \(rows)")
    }

    private func applyReferenceTables(in db: Database) throws {
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
        // Full-reference tables (v2). The registry replace runs before the legacy
        // `registryEntities` upsert in `applyComplicationTables` — those rows come from the same
        // phone table, so re-upserting a subset afterwards is a no-op, not a conflict.
        if let registry {
            try EntityRegistryListForDisplay.Entity.deleteAll(db)
            for entry in registry {
                try entry.insert(db)
            }
        }
        if let devices {
            try AppDeviceRegistry.deleteAll(db)
            for device in devices {
                try device.insert(db)
            }
        }
        // The watch seeds this table with the same defaults the phone does, so a replace (rather than
        // an upsert) is what lets a preset the user *removed* on the phone disappear from the watch.
        if let notificationSnoozeActions {
            try NotificationSnoozeAction.deleteAll(db)
            for action in notificationSnoozeActions {
                try action.insert(db)
            }
        }
    }

    private func applyComplicationTables(in db: Database, includeRegistryRows: Bool) throws {
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
        guard includeRegistryRows else { return }
        // The registry is keyed on (serverId, entityId) with no stable primary key, so a plain
        // save() re-inserts on the next sync and violates that unique index (SQLite error 19).
        // Replace on conflict to upsert just these rows without wiping the rest of the registry.
        for entity in registryEntities {
            try entity.insert(db, onConflict: .replace)
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
        if let registry, let data = try? encoder.encode(registry) {
            digests["registry"] = Self.digest(of: [data])
        }
        if let devices, let data = try? encoder.encode(devices) {
            digests["devices"] = Self.digest(of: [data])
        }
        // The complication tables travel and change together; one digest covers all three.
        if let complications, let complicationConfigs,
           let complicationsData = try? encoder.encode(complications),
           let configsData = try? encoder.encode(complicationConfigs),
           let entitiesData = try? encoder.encode(registryEntities) {
            digests["complications"] = Self.digest(of: [complicationsData, configsData, entitiesData])
        }
        if let notificationSnoozeActions, let data = try? encoder.encode(notificationSnoozeActions) {
            digests["notificationSnoozeActions"] = Self.digest(of: [data])
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
        if matches("registry") { copy.registry = nil }
        if matches("devices") { copy.devices = nil }
        if matches("complications") {
            copy.complications = nil
            copy.complicationConfigs = nil
            copy.registryEntities = []
        }
        if matches("notificationSnoozeActions") { copy.notificationSnoozeActions = nil }
        if matches("servers") { copy.servers = nil }
        return copy
    }
}
