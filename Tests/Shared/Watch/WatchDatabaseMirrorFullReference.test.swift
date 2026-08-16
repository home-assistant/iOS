import Foundation
import GRDB
@testable import Shared
import Testing

/// Tests for the full-reference (v2) watch database mirror: the version/compression wire constants,
/// snapshot fidelity per advertised version, the registry/device table retain-vs-replace semantics,
/// and payload compression.
@Suite(.serialized)
struct WatchDatabaseMirrorFullReferenceTests {
    @Test("Version and payload keys are stable wire constants")
    func constants() {
        #expect(WatchDatabaseMirror.versionKey == "mirrorVersion")
        #expect(WatchDatabaseMirror.compressedKey == "compressed")
        #expect(WatchDatabaseMirror.legacyVersion == 1)
        #expect(WatchDatabaseMirror.fullReferenceVersion == 2)
    }

    @Test("Registry and devices round-trip: nil retains, empty is authoritative")
    func retainSemantics() throws {
        let retain = WatchDatabaseMirror(entities: [], areas: [], pipelines: [])
        let retainDecoded = try WatchDatabaseMirror.decodeForWatchThrowing(retain.encodeForWatch())
        #expect(retainDecoded.registry == nil)
        #expect(retainDecoded.devices == nil)

        let authoritative = WatchDatabaseMirror(entities: [], areas: [], pipelines: [], registry: [], devices: [])
        let decoded = try WatchDatabaseMirror.decodeForWatchThrowing(authoritative.encodeForWatch())
        #expect(decoded.registry == [])
        #expect(decoded.devices == [])
    }

    @Test("Digests cover registry and devices, and matching digests omit them")
    func digestsAndOmission() {
        let mirror = WatchDatabaseMirror(
            entities: [],
            areas: [],
            pipelines: [],
            registry: [.init(serverId: "s1", entityId: "light.a", hidden: true)],
            devices: [Self.device(deviceId: "d1")]
        )
        let digests = mirror.tableDigests()
        #expect(digests["registry"] != nil)
        #expect(digests["devices"] != nil)

        let omitted = mirror.omittingTables(matching: digests, currentDigests: digests)
        #expect(omitted.registry == nil)
        #expect(omitted.devices == nil)

        // Digests that don't match keep the tables carried.
        let carried = mirror.omittingTables(matching: [:], currentDigests: digests)
        #expect(carried.registry != nil)
        #expect(carried.devices != nil)
    }

    @Test("Compression round-trips and rejects garbage")
    func compression() throws {
        // Round-trip correctness is the contract; no size assertion — the codec doesn't guarantee
        // a smaller output for arbitrary input.
        let payload = Data(repeating: 7, count: 200_000)
        let compressed = try WatchDatabaseMirror.compress(payload)
        try #expect(WatchDatabaseMirror.decompress(compressed) == payload)
        #expect(throws: (any Error).self) {
            _ = try WatchDatabaseMirror.decompress(Data([0x00, 0x01, 0x02]))
        }
    }

    @Test("Legacy snapshot serves the filtered slice; full-reference carries every table row")
    func snapshotFidelity() throws {
        try withDatabase { database in
            try database.write { db in
                try Self.entity(entityId: "light.visible", domain: "light").insert(db)
                try Self.entity(entityId: "light.hidden", domain: "light", isHidden: true).insert(db)
                // A domain the legacy mirror never carries.
                try Self.entity(entityId: "camera.garage", domain: "camera").insert(db)
                try EntityRegistryListForDisplay.Entity(serverId: "1", entityId: "light.hidden", hidden: true)
                    .insert(db)
                try EntityRegistryListForDisplay.Entity(serverId: "1", entityId: "light.visible").insert(db)
                try Self.device(deviceId: "d1").insert(db)
            }

            let legacy = try WatchDatabaseMirror.snapshot()
            #expect(legacy.entities?.map(\.entityId) == ["light.visible"])
            #expect(legacy.registry == nil)
            #expect(legacy.devices == nil)
            #expect(legacy.tableDigests()["registry"] == nil)
            #expect(legacy.tableDigests()["devices"] == nil)

            let full = try WatchDatabaseMirror.snapshot(version: WatchDatabaseMirror.fullReferenceVersion)
            #expect(full.entities?.map(\.entityId).sorted() == ["camera.garage", "light.hidden", "light.visible"])
            #expect(full.registry?.map(\.entityId).sorted() == ["light.hidden", "light.visible"])
            #expect(full.devices?.map(\.deviceId) == ["d1"])
        }
    }

    /// Regression: a phone whose reference tables read back empty (a refresh that fetched nothing, a
    /// reset, a rebuild in progress) used to send authoritative empty arrays, which deleted every
    /// mirrored row on the watch and left it unable to resolve any item.
    @Test("An empty phone table is carried as nil (retain), never as an authoritative wipe")
    func emptyTablesAreNotAuthoritative() throws {
        try withDatabase { database in
            // Areas exist; entities, registry and devices are empty — the state that wiped watches.
            try database.write { db in
                try Self.area(areaId: "kitchen").insert(db)
            }

            for version in [WatchDatabaseMirror.legacyVersion, WatchDatabaseMirror.fullReferenceVersion] {
                let snapshot = try WatchDatabaseMirror.snapshot(version: version)
                #expect(snapshot.entities == nil)
                #expect(snapshot.registry == nil)
                #expect(snapshot.devices == nil)
                #expect(snapshot.pipelines == nil)
                // The table that does have rows is still carried.
                #expect(snapshot.areas?.map(\.areaId) == ["kitchen"])
                // A table that isn't carried publishes no digest, so it can never be "matched" and
                // skipped on a later sync once the phone has rows again.
                let digests = snapshot.tableDigests()
                #expect(digests["entities"] == nil)
                #expect(digests["registry"] == nil)
                #expect(snapshot.carriedDigestKeys.contains("areas"))
                #expect(!snapshot.carriedDigestKeys.contains("entities"))
            }
        }
    }

    /// Regression: a watch whose tables were wiped kept echoing digests claiming it still held them,
    /// so the phone omitted those tables on every sync. Nothing ever refilled them, the home screen
    /// could resolve no names (falling back to entity ids) and each sync carried almost no data.
    @Test("Digests are reported stale for tables that are empty locally")
    func emptyLocalTablesInvalidateTheirDigests() throws {
        try withDatabase { database in
            // Nothing stored yet: every mirrored table is empty, so no digest may be trusted.
            let everyTable: Set<String> = ["entities", "areas", "pipelines", "registry", "devices"]
            #expect(WatchDatabaseMirror.digestKeysForEmptyLocalTables() == everyTable)

            try database.write { db in
                try Self.entity(entityId: "light.kitchen", domain: "light").insert(db)
                try Self.area(areaId: "kitchen").insert(db)
            }

            // The tables that now hold rows drop out; the still-empty ones remain stale.
            let stale = WatchDatabaseMirror.digestKeysForEmptyLocalTables()
            #expect(!stale.contains("entities"))
            #expect(!stale.contains("areas"))
            #expect(stale == ["pipelines", "registry", "devices"])
        }
    }

    @Test("carriedDigestKeys tracks exactly the tables a payload holds")
    func carriedKeys() {
        let full = WatchDatabaseMirror(
            entities: [],
            areas: [],
            pipelines: [],
            registry: [],
            devices: [],
            complications: [],
            complicationConfigs: [],
            servers: Data()
        )
        #expect(full.carriedDigestKeys == [
            "entities",
            "areas",
            "pipelines",
            "registry",
            "devices",
            "complications",
            "servers",
        ])

        // Delta payloads carry only what changed.
        let delta = WatchDatabaseMirror(entities: nil, areas: [], pipelines: nil)
        #expect(delta.carriedDigestKeys == ["areas"])

        // The complication group needs both halves to count as carried.
        let halfComplications = WatchDatabaseMirror(
            entities: nil,
            areas: nil,
            pipelines: nil,
            complications: []
        )
        #expect(halfComplications.carriedDigestKeys.isEmpty)
    }

    @Test("Applying a mirror replaces the registry and device tables; nil retains them")
    func applySemantics() throws {
        try withDatabase { database in
            try database.write { db in
                try EntityRegistryListForDisplay.Entity(serverId: "1", entityId: "light.old").insert(db)
                try Self.device(deviceId: "old").insert(db)
            }

            let mirror = WatchDatabaseMirror(
                entities: nil,
                areas: nil,
                pipelines: nil,
                registry: [.init(serverId: "1", entityId: "light.new")],
                devices: [Self.device(deviceId: "new")]
            )
            try mirror.apply()
            let (registryRows, deviceRows) = try database.read { db in
                try (
                    EntityRegistryListForDisplay.Entity.fetchAll(db).map(\.entityId),
                    AppDeviceRegistry.fetchAll(db).map(\.deviceId)
                )
            }
            #expect(registryRows == ["light.new"])
            #expect(deviceRows == ["new"])

            // A mirror without the tables (delta sync) retains the local rows.
            try WatchDatabaseMirror(entities: nil, areas: nil, pipelines: nil).apply()
            let retained = try database.read { db in
                try AppDeviceRegistry.fetchAll(db).map(\.deviceId)
            }
            #expect(retained == ["new"])
        }
    }

    /// Regression: snooze presets edited on the iPhone never reached the Apple Watch, which builds its
    /// notification actions from its own copy of this table and so stayed on the seeded 5/15/60.
    @Test("Snooze presets are mirrored, and an empty set is authoritative rather than retained")
    func snoozeActionsAreMirrored() throws {
        try withDatabase { database in
            // The table seeds 5/15/60; replace it with an edited set, as the settings screen would.
            try database.write { db in
                try NotificationSnoozeAction.deleteAll(db)
                try NotificationSnoozeAction(id: "a", minutes: 30, sortOrder: 1).insert(db)
                try NotificationSnoozeAction(id: "b", minutes: 10, isEnabled: false, sortOrder: 0).insert(db)
            }

            for version in [WatchDatabaseMirror.legacyVersion, WatchDatabaseMirror.fullReferenceVersion] {
                let snapshot = try WatchDatabaseMirror.snapshot(version: version)
                // Carried in the sort order the watch renders them in.
                #expect(snapshot.notificationSnoozeActions?.map(\.minutes) == [10, 30])
                #expect(snapshot.notificationSnoozeActions?.map(\.isEnabled) == [false, true])
                #expect(snapshot.carriedDigestKeys.contains("notificationSnoozeActions"))
                #expect(snapshot.tableDigests()["notificationSnoozeActions"] != nil)
            }

            // Round-trips over the wire, and matching digests omit it from the next delta sync.
            let snapshot = try WatchDatabaseMirror.snapshot()
            let decoded = try WatchDatabaseMirror.decodeForWatchThrowing(snapshot.encodeForWatch())
            #expect(decoded.notificationSnoozeActions?.map(\.minutes) == [10, 30])
            let digests = snapshot.tableDigests()
            #expect(snapshot.omittingTables(matching: digests, currentDigests: digests)
                .notificationSnoozeActions == nil)
            #expect(snapshot.omittingTables(matching: [:], currentDigests: digests)
                .notificationSnoozeActions != nil)

            // Applying replaces the local presets outright, so one removed on the phone disappears.
            try decoded.apply()
            let applied = try Self.storedMinutes(in: database)
            #expect(applied == [10, 30])

            // Deleting every preset on the phone is a real choice: it must propagate, not be retained.
            try database.write { db in try NotificationSnoozeAction.deleteAll(db) }
            let emptied = try WatchDatabaseMirror.snapshot()
            #expect(emptied.notificationSnoozeActions == [])
            try emptied.apply()
            let afterWipe = try Self.storedMinutes(in: database)
            #expect(afterWipe.isEmpty)

            // A delta payload that doesn't carry the table retains whatever the watch holds.
            try database.write { db in
                try NotificationSnoozeAction(id: "c", minutes: 45, sortOrder: 0).insert(db)
            }
            try WatchDatabaseMirror(entities: nil, areas: nil, pipelines: nil).apply()
            let retained = try Self.storedMinutes(in: database)
            #expect(retained == [45])
        }
    }

    // MARK: - Fixtures

    /// The locally stored snooze presets, in the order the watch would render them.
    private static func storedMinutes(in database: DatabaseQueue) throws -> [Int] {
        try database.read { db in
            try NotificationSnoozeAction
                .order(Column(DatabaseTables.NotificationSnoozeAction.sortOrder.rawValue))
                .fetchAll(db)
                .map(\.minutes)
        }
    }

    private static func entity(
        entityId: String,
        domain: String,
        serverId: String = "1",
        isHidden: Bool? = nil
    ) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: domain,
            name: entityId,
            icon: nil,
            rawDeviceClass: nil,
            isHidden: isHidden
        )
    }

    private static func area(areaId: String, serverId: String = "1") -> AppArea {
        .init(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: areaId.capitalized,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: []
        )
    }

    private static func device(deviceId: String, serverId: String = "1") -> AppDeviceRegistry {
        .init(
            serverId: serverId,
            deviceId: deviceId,
            areaId: nil,
            configurationURL: nil,
            configEntries: nil,
            configEntriesSubentries: nil,
            connections: nil,
            createdAt: nil,
            disabledBy: nil,
            entryType: nil,
            hwVersion: nil,
            identifiers: nil,
            labels: nil,
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: nil,
            nameByUser: nil,
            name: nil,
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )
    }

    /// In-memory database with every table `snapshot()`/`apply()` touches, plus a fake server
    /// manager (`snapshot()` reads `Current.servers.restorableState()`).
    private func withDatabase(perform work: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let database = try DatabaseQueue(path: ":memory:")
        let tables: [DatabaseTableProtocol] = [
            HAppEntityTable(),
            DisplayEntityRegistryTable(),
            AppDeviceRegistryTable(),
            AppAreaTable(),
            AssistPipelinesTable(),
            NotificationSnoozeActionTable(),
        ]
        for table in tables {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
        Current.servers = FakeServerManager()
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        try work(database)
    }
}
