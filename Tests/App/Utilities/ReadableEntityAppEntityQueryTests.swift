import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind "get entity state": it offers what a person would ask about,
/// and leaves out what they would not.
struct ReadableEntityAppEntityQueryTests {
    private static func makeEntity(
        serverId: String,
        entityId: String,
        name: String,
        entityCategory: Int? = nil,
        isHidden: Bool? = nil
    ) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: entityCategory,
            isHidden: isHidden
        )
    }

    private func seed(serverId: String, entities: [HAAppEntity]) async throws {
        try await Current.database().write { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .deleteAll(db)
            for entity in entities {
                try entity.insert(db)
            }
        }
    }

    private func seedArea(serverId: String, name: String, entities: Set<String>) async throws {
        try await Current.database().write { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .deleteAll(db)
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: name,
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: entities,
                floorId: nil,
                floorName: nil
            ).insert(db)
        }
    }

    private func withFakeServer(_ body: (String) async throws -> Void) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        defer { Current.servers = previous }
        Current.servers = manager
        try await body(server.identifier.rawValue)
    }

    /// The three kinds nobody asks Siri about: a diagnostic reading, a configuration control, and
    /// an entity the user hid.
    @Test func leavesOutDiagnosticConfigurationAndHiddenEntities() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "sensor.temperature", name: "Temperature"),
                Self.makeEntity(serverId: serverId, entityId: "sensor.uptime", name: "Uptime", entityCategory: 1),
                Self.makeEntity(serverId: serverId, entityId: "switch.led", name: "LED", entityCategory: 2),
                Self.makeEntity(serverId: serverId, entityId: "light.hidden", name: "Hidden", isHidden: true),
            ])
            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["sensor.temperature", "sensor.uptime", "switch.led", "light.hidden"]
            )
            let collection = try await ReadableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("sensor.temperature"))
            #expect(!ids.contains("sensor.uptime"))
            #expect(!ids.contains("switch.led"))
            #expect(!ids.contains("light.hidden"))
        }
    }

    /// An entity in no room is one nobody names out loud.
    @Test func leavesOutEntitiesWithNoArea() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "light.orphan", name: "Orphan"),
            ])
            try await seedArea(serverId: serverId, name: "Kitchen", entities: ["light.kitchen"])
            let collection = try await ReadableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("light.kitchen"))
            #expect(!ids.contains("light.orphan"))
        }
    }

    @Test func resolvesAndMatchesByName() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity")
            try await seed(serverId: serverId, entities: [entity])
            try await seedArea(serverId: serverId, name: "Bathroom", entities: ["sensor.humidity"])

            let resolved = try await ReadableEntityAppEntityQuery().entities(for: [entity.id])
            #expect(resolved.first?.entityId == "sensor.humidity")
            #expect(resolved.first?.displayString == "Humidity")

            let matched = try await ReadableEntityAppEntityQuery().entities(matching: "humid")
            #expect(matched.sections.flatMap(\.items).map(\.value.entityId).contains("sensor.humidity"))
        }
    }
}
