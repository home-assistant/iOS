import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind "open" and "close": it offers only the domains whose services
/// actually open and close, so a light never appears among them.
struct OpenableEntityAppEntityQueryTests {
    private static func makeEntity(serverId: String, entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: nil
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

    @Test func offersCoversAndNothingElse() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "cover.garage", name: "Garage"),
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "switch.desk", name: "Desk"),
            ])
            try await seedArea(
                serverId: serverId,
                name: "Ground floor",
                entities: ["cover.garage", "light.kitchen", "switch.desk"]
            )
            let collection = try await OpenableEntityAppEntityQuery().suggestedEntities()
            let items = collection.sections.flatMap(\.items).map(\.value)
            #expect(items.filter { $0.areaTarget == nil }.map(\.entityId) == ["cover.garage"])
            // The room is offered as a target too, and only for what this command can open: the
            // light and the switch sharing the area contribute none of their own.
            #expect(items.filter { $0.areaTarget != nil }.map(\.domain) == [.cover])
        }
    }

    @Test func resolvesACoverByIdentifier() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "cover.curtain", name: "Curtain")
            try await seed(serverId: serverId, entities: [entity])
            try await seedArea(serverId: serverId, name: "Living room", entities: ["cover.curtain"])
            let resolved = try await OpenableEntityAppEntityQuery().entities(for: [entity.id])
            #expect(resolved.count == 1)
            #expect(resolved.first?.entityId == "cover.curtain")
            #expect(resolved.first?.displayString == "Curtain")
            #expect(resolved.first?.domain == .cover)
        }
    }

    @Test func matchesOnName() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "cover.curtain", name: "Curtain"),
                Self.makeEntity(serverId: serverId, entityId: "cover.garage", name: "Garage"),
            ])
            try await seedArea(serverId: serverId, name: "Ground floor", entities: ["cover.curtain", "cover.garage"])
            let collection = try await OpenableEntityAppEntityQuery().entities(matching: "curtain")
            let names = collection.sections.flatMap(\.items).map(\.value.displayString)
            #expect(names == ["Curtain"])
        }
    }
}
