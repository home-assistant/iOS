import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Building a mirror from the phone's tables (including the entities the watch home screen and its
/// complications show) and applying a mirror on the receiving side. Each test reads and writes its
/// own in-memory database through `Current`, on the test's task.
@Suite(.isolatedEnvironment)
struct WatchDatabaseMirrorApplyTests {
    @discardableResult
    private func installDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
        return database
    }

    private func entity(_ entityId: String, serverId: String = "s1") -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: entityId,
            icon: nil,
            rawDeviceClass: nil
        )
    }

    @Test func snapshotCarriesPrecisionForHomeAndComplicationEntities() throws {
        let database = try installDatabase()
        var folder = MagicItem(id: "folder", serverId: "s1", type: .folder)
        folder.items = [MagicItem(id: "sensor.nested", serverId: "s1", type: .entity)]
        try database.write { db in
            try WatchConfig(
                id: WatchConfig.watchConfigId,
                items: [
                    MagicItem(id: "sensor.home", serverId: "s1", type: .entity),
                    MagicItem(id: "script.x", serverId: "s1", type: .script),
                    folder,
                ]
            ).insert(db)
            try WatchComplicationConfig(id: "c", serverId: "s2", entityId: "sensor.face").insert(db)
            for (serverId, entityId) in [
                ("s1", "sensor.home"),
                ("s1", "sensor.nested"),
                ("s2", "sensor.face"),
                ("s1", "sensor.unrelated"),
            ] {
                try EntityRegistryListForDisplay.Entity(serverId: serverId, entityId: entityId, decimalPlaces: 1)
                    .insert(db)
            }
        }

        let mirror = try WatchDatabaseMirror.snapshot()
        #expect(mirror.registryEntities.map(\.entityId) == ["sensor.home", "sensor.nested", "sensor.face"])
        #expect(mirror.complicationConfigs?.map(\.id) == ["c"])
    }

    @Test func applyingReplacesCarriedTablesAndUpsertsPrecisionRows() throws {
        let database = try installDatabase()
        try database.write { db in
            try entity("light.stale").insert(db)
            try NotificationSnoozeAction(minutes: 99, sortOrder: 0).insert(db)
            try EntityRegistryListForDisplay.Entity(serverId: "s1", entityId: "sensor.kept").insert(db)
        }

        let mirror = WatchDatabaseMirror(
            entities: [entity("light.fresh")],
            areas: [AppArea(
                id: "s1-kitchen",
                serverId: "s1",
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: []
            )],
            pipelines: [],
            complications: [WatchComplication(identifier: "legacy")],
            complicationConfigs: [WatchComplicationConfig(id: "config", serverId: "s1")],
            registryEntities: [EntityRegistryListForDisplay.Entity(
                serverId: "s1",
                entityId: "sensor.temp",
                decimalPlaces: 2
            )],
            notificationSnoozeActions: [NotificationSnoozeAction(minutes: 10, sortOrder: 0)]
        )
        let decoded = try WatchDatabaseMirror.decodeForWatchThrowing(mirror.encodeForWatch())
        try decoded.apply()

        let (entities, areas, complications, configs, snoozes, registry) = try database.read { db in
            try (
                HAAppEntity.fetchAll(db).map(\.entityId),
                AppArea.fetchAll(db).map(\.areaId),
                WatchComplication.fetchAll(db).map(\.identifier),
                WatchComplicationConfig.fetchAll(db).map(\.id),
                NotificationSnoozeAction.fetchAll(db).map(\.minutes),
                EntityRegistryListForDisplay.Entity.fetchAll(db).map(\.entityId).sorted()
            )
        }
        #expect(entities == ["light.fresh"])
        #expect(areas == ["kitchen"])
        #expect(complications == ["legacy"])
        #expect(configs == ["config"])
        #expect(snoozes == [10])
        #expect(registry == ["sensor.kept", "sensor.temp"])
    }

    @Test func complicationAndSnoozeTablesHaveDigestsAndCanBeOmitted() {
        let mirror = WatchDatabaseMirror(
            entities: nil,
            areas: nil,
            pipelines: nil,
            complications: [],
            complicationConfigs: [],
            registryEntities: [],
            notificationSnoozeActions: [NotificationSnoozeAction(minutes: 5, sortOrder: 0)]
        )
        let digests = mirror.tableDigests()
        #expect(digests["complications"] != nil)
        #expect(digests["notificationSnoozeActions"] != nil)

        let omitted = mirror.omittingTables(matching: digests, currentDigests: digests)
        #expect(omitted.complications == nil)
        #expect(omitted.complicationConfigs == nil)
        #expect(omitted.notificationSnoozeActions == nil)
        #expect(omitted.carriedDigestKeys.isEmpty)
    }
}
