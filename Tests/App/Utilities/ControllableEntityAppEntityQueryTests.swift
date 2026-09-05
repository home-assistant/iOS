import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind the spoken on/off commands: it offers the domains a command can
/// switch, and nothing else.
struct ControllableEntityAppEntityQueryTests {
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

    /// Areas carry their entities, which is also how an entity inherits its device's area.
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

            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["light.kitchen", "cover.garage", "sensor.humidity", "scene.movie"]
            )

            let collection = try await ControllableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("light.kitchen"))
            #expect(ids.contains("cover.garage"))
            // A scene is offered, though only "turn on" reaches it.
            #expect(ids.contains("scene.movie"))
            // Nothing to switch on a sensor.
            #expect(!ids.contains("sensor.humidity"))
        }
    }

    @Test func resolvesEntitiesByIdentifier() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "switch.desk", name: "Desk")
            try await seed(serverId: serverId, entities: [entity])

            try await seedArea(serverId: serverId, name: "Study", entities: ["switch.desk"])

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

            // Neutral area name: the search index also matches on area, and "Kitchen" there would
            // pull in the porch light too.
            try await seedArea(serverId: serverId, name: "Ground floor", entities: ["light.kitchen", "light.porch"])

            let collection = try await ControllableEntityAppEntityQuery().entities(matching: "kitchen")
            let names = collection.sections.flatMap(\.items).map(\.value.displayString)

            #expect(names.contains("Kitchen ceiling"))
            #expect(!names.contains("Porch"))
        }
    }

    @Test func subtitleNamesTheServerOnlyWhenThereIsMoreThanOne() async throws {
        let entity = ControllableEntityAppEntity(
            id: "s1-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s1",
            serverName: "Cabin",
            areaName: "Kitchen",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        )

        let previous = Current.servers
        defer { Current.servers = previous }

        Current.servers = FakeServerManager(initial: 1)
        #expect(entity.subtitle == "Kitchen")

        Current.servers = FakeServerManager(initial: 2)
        #expect(entity.subtitle == "Cabin • Kitchen")
    }

    @Test func skipsConfigurationDiagnosticHiddenAndRoomlessEntities() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "switch.restart", name: "Restart", entityCategory: 0),
                Self.makeEntity(serverId: serverId, entityId: "switch.secret", name: "Secret", isHidden: true),
                Self.makeEntity(serverId: serverId, entityId: "light.nowhere", name: "Nowhere"),
            ])
            // Everything but `light.nowhere` has a room.
            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["light.kitchen", "switch.restart", "switch.secret"]
            )

            let collection = try await ControllableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids == ["light.kitchen"])
        }
    }

    /// A scene is named by whoever made it, so it belongs in the list with no room at all.
    @Test func keepsScenesAndGroupsThatHaveNoArea() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "scene.movie_time", name: "Movie time"),
                Self.makeEntity(serverId: serverId, entityId: "group.downstairs", name: "Downstairs"),
                Self.makeEntity(serverId: serverId, entityId: "light.nowhere", name: "Nowhere"),
            ])
            try await seedArea(serverId: serverId, name: "Hall", entities: [])

            let collection = try await ControllableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("scene.movie_time"))
            #expect(ids.contains("group.downstairs"))
            // A light with no room stays out.
            #expect(!ids.contains("light.nowhere"))
        }
    }
}
