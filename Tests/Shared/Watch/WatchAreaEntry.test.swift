import GRDB
@testable import Shared
import Testing

/// Coverage for the area entries the watch configuration can hold: which areas may be added, and
/// how a `.area` magic item resolves its name and icon.
@Suite(.serialized)
struct WatchAreaEntryTests {
    @Test("Only areas holding a watch-compatible entity are addable")
    func dropsAreasWithoutWatchCompatibleEntities() throws {
        try withDatabase { database in
            try database.write { db in
                // A light: a domain the watch can both add and render.
                try Self.entity(entityId: "light.living_room", domain: "light").insert(db)
                // A camera: the watch streams it on its own screen, so its area counts too.
                try Self.entity(entityId: "camera.garage", domain: "camera").insert(db)
                // A media player: the watch renders no screen for it, so its area must not be offered.
                try Self.entity(entityId: "media_player.tv", domain: "media_player").insert(db)
                // A diagnostic entity is filtered out even though its domain is addable.
                try Self.entity(entityId: "sensor.uptime", domain: "sensor", entityCategory: 1).insert(db)

                try Self.area(areaId: "living_room", entities: ["light.living_room"]).insert(db)
                try Self.area(areaId: "garage", entities: ["camera.garage"]).insert(db)
                try Self.area(areaId: "media_room", entities: ["media_player.tv"]).insert(db)
                try Self.area(areaId: "attic", entities: ["sensor.uptime"]).insert(db)
                try Self.area(areaId: "empty", entities: []).insert(db)
                // Same entity id on another server: scoping must keep that area out of server 1's list.
                try Self.area(areaId: "office", serverId: "2", entities: ["light.living_room"]).insert(db)
            }

            // Ordered by name: "Garage" before "Living Room".
            let addableAreas = try AppArea.fetchWatchPopulatedAreas(for: "1")
            #expect(addableAreas.map(\.areaId) == ["garage", "living_room"])
        }
    }

    /// Area entries reference an area, not an entity, so their info comes from the areas table.
    @Test("An area item resolves its name and icon from the areas table")
    func areaItemInfoComesFromTheAreasTable() throws {
        try withDatabase { database in
            try database.write { db in
                try Self.area(
                    areaId: "living_room",
                    icon: "mdi:sofa",
                    entities: ["light.living_room"]
                ).insert(db)
            }

            let provider = MagicItemProvider()
            let info = provider.getInfo(for: .init(id: "living_room", serverId: "1", type: .area))
            #expect(info?.id == "1-living_room")
            #expect(info?.name == "Living Room")
            #expect(info?.iconName == "mdi:sofa")

            // An area the database doesn't know resolves to nothing, like a missing entity does…
            #expect(provider.getInfo(for: .init(id: "garage", serverId: "1", type: .area)) == nil)
            // …and another server's areas are never borrowed.
            #expect(provider.getInfo(for: .init(id: "living_room", serverId: "2", type: .area)) == nil)
        }
    }

    private static func entity(
        entityId: String,
        domain: String,
        serverId: String = "1",
        entityCategory: Int? = nil
    ) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: domain,
            name: entityId,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: entityCategory
        )
    }

    private static func area(
        areaId: String,
        serverId: String = "1",
        icon: String? = nil,
        entities: Set<String>
    ) -> AppArea {
        .init(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: areaId.split(separator: "_").map(\.capitalized).joined(separator: " "),
            aliases: [],
            picture: nil,
            icon: icon,
            sortOrder: nil,
            entities: entities
        )
    }

    private func withDatabase(perform work: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppAreaTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try work(database)
    }
}
