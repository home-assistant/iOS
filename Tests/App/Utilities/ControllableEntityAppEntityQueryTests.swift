import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind the spoken on/off commands: it offers the domains a command can
/// switch, and nothing else.
struct ControllableEntityAppEntityQueryTests {
    private static func makeEntity(serverId: String, entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil
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

    /// Points `Current` at a single fake server whose entities are the ones seeded, and restores it.
    private func withFakeServer(
        _ body: (String) async throws -> Void
    ) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        defer { Current.servers = previous }
        Current.servers = manager
        try await body(server.identifier.rawValue)
    }

    @Test func offersSwitchableDomainsAndSkipsReadOnlyOnes() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "cover.garage", name: "Garage"),
                Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity"),
                Self.makeEntity(serverId: serverId, entityId: "scene.movie", name: "Movie"),
            ])

            let collection = try await ControllableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("light.kitchen"))
            #expect(ids.contains("cover.garage"))
            // A sensor cannot be switched, and a scene's "off" would re-activate it.
            #expect(!ids.contains("sensor.humidity"))
            #expect(!ids.contains("scene.movie"))
        }
    }

    @Test func resolvesEntitiesByIdentifier() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "switch.desk", name: "Desk")
            try await seed(serverId: serverId, entities: [entity])

            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [entity.id])

            #expect(resolved.count == 1)
            #expect(resolved.first?.entityId == "switch.desk")
            #expect(resolved.first?.displayString == "Desk")
            #expect(resolved.first?.domain == .switch)
        }
    }

    @Test func matchesOnName() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen ceiling"),
                Self.makeEntity(serverId: serverId, entityId: "light.porch", name: "Porch"),
            ])

            let collection = try await ControllableEntityAppEntityQuery().entities(matching: "kitchen")
            let names = collection.sections.flatMap(\.items).map(\.value.displayString)

            #expect(names.contains("Kitchen ceiling"))
            #expect(!names.contains("Porch"))
        }
    }
}
