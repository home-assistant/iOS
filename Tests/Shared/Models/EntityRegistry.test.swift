import Foundation
import GRDB
import HAKit
@testable import Shared
import Testing

@Suite("Entity Registry Tests")
struct EntityRegistryTests {
    @Test("isHidden reflects the hidden flag")
    func isHiddenReflectsFlag() {
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x", hidden: true).isHidden == true)
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x", hidden: false).isHidden == false)
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x").isHidden == false)
    }

    @Test("serverId defaults to empty and is assignable before persistence")
    func serverIdAssignable() {
        var entity = EntityRegistryListForDisplay.Entity(entityId: "x")
        #expect(entity.serverId == "")
        entity.serverId = "server-1"
        #expect(entity.serverId == "server-1")
    }

    @Test("Retains display fields and the raw entity category index")
    func retainsFields() {
        let entity = EntityRegistryListForDisplay.Entity(
            entityId: "sensor.temperature",
            deviceId: "device-123",
            name: "Temperatura",
            entityCategory: 1,
            decimalPlaces: 1,
            areaId: "bedroom"
        )

        #expect(entity.entityId == "sensor.temperature")
        #expect(entity.deviceId == "device-123")
        #expect(entity.name == "Temperatura")
        #expect(entity.entityCategory == 1)
        #expect(entity.decimalPlaces == 1)
        #expect(entity.areaId == "bedroom")
    }
}

@Suite("AppEntitiesModel display-name resolution")
struct AppEntitiesModelNameResolutionTests {
    private func makeEntity(_ entityId: String, friendlyName: String?) throws -> HAEntity {
        var attributes: [String: Any] = [:]
        if let friendlyName {
            attributes["friendly_name"] = friendlyName
        }
        return try HAEntity(
            entityId: entityId,
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "context", userId: "user", parentId: nil)
        )
    }

    /// `AppEntitiesModel` bakes the registry display name (`list_for_display` `en`) into
    /// `HAAppEntity.name` at write time, falling back to the live `friendly_name`, then the entity id.
    /// A second pass with identical data leaves the names stable — the skip-write compares
    /// display-name vs display-name, so an unchanged refresh does not churn the table.
    @Test("name resolves to registry en, else friendly_name, else entityId; and is idempotent")
    func resolvesAndPersistsDisplayName() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let serverId = "name-resolution-test"
        let server = Server.fake(identifier: .init(rawValue: serverId))

        // Seed the registry: "light.kitchen" has a custom name (`en`); the others have no registry row.
        try await database.write { db in
            var registry = EntityRegistryListForDisplay.Entity(entityId: "light.kitchen", name: "Custom Kitchen")
            registry.serverId = serverId
            try registry.insert(db)
        }

        let entities: Set<HAEntity> = try [
            makeEntity("light.kitchen", friendlyName: "Kitchen Light"),
            makeEntity("switch.pump", friendlyName: "Pump"),
            makeEntity("sensor.untitled", friendlyName: nil),
        ]

        func storedNames() async throws -> [String: String] {
            let rows = try await database.read { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.entityId, $0.name) })
        }

        await AppEntitiesModel().updateModel(entities, server: server)
        let names = try await storedNames()
        #expect(names["light.kitchen"] == "Custom Kitchen") // registry `en` preferred over friendly_name
        #expect(names["switch.pump"] == "Pump") // falls back to friendly_name
        #expect(names["sensor.untitled"] == "sensor.untitled") // falls back to entityId

        // Idempotent: a second pass with identical data + registry keeps the resolved names stable.
        await AppEntitiesModel().updateModel(entities, server: server)
        let namesAfterSecondPass = try await storedNames()
        #expect(namesAfterSecondPass == names)
    }

    /// The registry hidden flag is baked into `HAAppEntity.isHidden` at write time, so consumers
    /// that never receive the full registry (the watch) can exclude hidden entities locally.
    @Test("isHidden is copied from the registry at write time")
    func persistsRegistryHiddenFlag() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let serverId = "hidden-flag-test"
        let server = Server.fake(identifier: .init(rawValue: serverId))

        // "light.hidden" is hidden in the registry; "light.visible" has a registry row without the
        // flag; "light.unregistered" has no registry row at all.
        try await database.write { db in
            try EntityRegistryListForDisplay.Entity(serverId: serverId, entityId: "light.hidden", hidden: true)
                .insert(db)
            try EntityRegistryListForDisplay.Entity(serverId: serverId, entityId: "light.visible")
                .insert(db)
        }

        let entities: Set<HAEntity> = try [
            makeEntity("light.hidden", friendlyName: "Hidden Light"),
            makeEntity("light.visible", friendlyName: "Visible Light"),
            makeEntity("light.unregistered", friendlyName: "Unregistered Light"),
        ]

        await AppEntitiesModel().updateModel(entities, server: server)

        let rows = try await database.read { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        #expect(rows.count == 3)
        func row(_ entityId: String) throws -> HAAppEntity {
            try #require(rows.first { $0.entityId == entityId })
        }
        try #expect(row("light.hidden").isHidden == true)
        // Not-hidden and unregistered entities stay `nil`, mirroring how `entityCategory` is baked.
        try #expect(row("light.visible").isHidden == nil)
        try #expect(row("light.unregistered").isHidden == nil)
    }

    /// Persistence is domain-agnostic: Spotlight, the entity pickers and templating all read the
    /// local database, so every domain the server reports is stored (including the assist, notify,
    /// image and geo_location ones that used to be dropped, and domains the `Domain` enum
    /// doesn't know). Features that support only some domains filter where they read.
    @Test("every domain is persisted, including ones no feature supports")
    func persistsEveryDomain() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let serverId = "all-domains-test"
        let server = Server.fake(identifier: .init(rawValue: serverId))

        let entityIds = [
            "light.kitchen",
            "geo_location.nearby_fire",
            "conversation.home_assistant",
            "stt.whisper",
            "tts.piper",
            "wake_word.openwakeword",
            "assist_satellite.kitchen_speaker",
            "notify.mobile_app_iphone",
            "image.doorbell_snapshot",
            "some_custom_integration.thing",
        ]
        let entities = try Set(entityIds.map { try makeEntity($0, friendlyName: nil) })

        await AppEntitiesModel().updateModel(entities, server: server)

        let storedEntityIds = try await database.read { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .fetchAll(db)
                .map(\.entityId)
        }
        #expect(Set(storedEntityIds) == Set(entityIds))
    }
}
