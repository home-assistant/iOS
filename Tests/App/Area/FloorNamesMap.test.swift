import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

// Exercises the database-backed floor disambiguation: `floorNamesMap(for:)` and an entity's
// `contextualSubtitle`, which only attach the floor when an area name collides on the same server.
struct FloorNamesMapTests {
    private static func makeArea(
        serverId: String,
        areaId: String,
        name: String,
        floorName: String?,
        entities: Set<String>
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities,
            floorId: floorName.map { "floor-\($0)" },
            floorName: floorName
        )
    }

    private func seed(serverId: String, areas: [AppArea]) async throws {
        try await Current.database().write { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .deleteAll(db)
            for area in areas {
                try area.insert(db)
            }
        }
    }

    @Test func floorNamesMapOnlyIncludesCollidingAreaNames() async throws {
        let serverId = "floormap-collision"
        try await seed(serverId: serverId, areas: [
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_up",
                name: "Bedroom",
                floorName: "Upstairs",
                entities: ["light.bedroom_up"]
            ),
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_down",
                name: "Bedroom",
                floorName: "Downstairs",
                entities: ["light.bedroom_down"]
            ),
            Self.makeArea(
                serverId: serverId,
                areaId: "kitchen",
                name: "Kitchen",
                floorName: "Ground",
                entities: ["light.kitchen"]
            ),
        ])

        let map = [HAAppEntity]().floorNamesMap(for: serverId)

        #expect(map["light.bedroom_up"] == "Upstairs")
        #expect(map["light.bedroom_down"] == "Downstairs")
        // Kitchen's name is unique, so no floor is attached even though it has one.
        #expect(map["light.kitchen"] == nil)
    }

    @Test func floorNamesMapIsEmptyWhenNoFloorsOnCollision() async throws {
        let serverId = "floormap-nofloor"
        try await seed(serverId: serverId, areas: [
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_a",
                name: "Bedroom",
                floorName: nil,
                entities: ["light.a"]
            ),
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_b",
                name: "Bedroom",
                floorName: nil,
                entities: ["light.b"]
            ),
        ])

        #expect([HAAppEntity]().floorNamesMap(for: serverId).isEmpty)
    }

    @Test func contextualSubtitleIncludesFloorWhenAreaNameCollides() async throws {
        let serverId = "floormap-subtitle"
        try await seed(serverId: serverId, areas: [
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_up",
                name: "Bedroom",
                floorName: "Upstairs",
                entities: ["light.bedroom_up"]
            ),
            Self.makeArea(
                serverId: serverId,
                areaId: "bedroom_down",
                name: "Bedroom",
                floorName: "Downstairs",
                entities: ["light.bedroom_down"]
            ),
            Self.makeArea(
                serverId: serverId,
                areaId: "kitchen",
                name: "Kitchen",
                floorName: "Ground",
                entities: ["light.kitchen"]
            ),
        ])

        let collidingEntity = HAAppEntity(
            id: "\(serverId)-light.bedroom_up",
            entityId: "light.bedroom_up",
            serverId: serverId,
            domain: "light",
            name: "Bedroom Light",
            icon: nil,
            rawDeviceClass: nil
        )
        #expect(collidingEntity.contextualSubtitle == "Upstairs • Bedroom")

        let uniqueEntity = HAAppEntity(
            id: "\(serverId)-light.kitchen",
            entityId: "light.kitchen",
            serverId: serverId,
            domain: "light",
            name: "Kitchen Light",
            icon: nil,
            rawDeviceClass: nil
        )
        #expect(uniqueEntity.contextualSubtitle == "Kitchen")
    }
}
