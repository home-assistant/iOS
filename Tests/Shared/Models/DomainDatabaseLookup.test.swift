import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Database lookups that read `Current.database()` synchronously on the test's task.
@Suite(.isolatedEnvironment)
struct DomainDatabaseLookupTests {
    private func installDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try database.createSchemaWithPrivateDefaults()
        Current.database = { database }
        return database
    }

    @Test func deviceClassComesFromTheStoredEntity() throws {
        let database = try installDatabase()
        try database.write { db in
            try HAAppEntity(
                id: "server-binary_sensor.door",
                entityId: "binary_sensor.door",
                serverId: "server",
                domain: "binary_sensor",
                name: "Door",
                icon: nil,
                rawDeviceClass: "door"
            ).insert(db)
        }
        #expect(DeviceClassProvider.deviceClass(for: "binary_sensor.door", serverId: "server") == .door)
        #expect(DeviceClassProvider.deviceClass(for: "binary_sensor.door", serverId: "other") == .unknown)
    }

    @Test func deviceClassIsUnknownWhenTheDatabaseFails() throws {
        let database = try DatabaseQueue()
        Current.database = { database }
        #expect(DeviceClassProvider.deviceClass(for: "light.x", serverId: "server") == .unknown)
    }

    @Test func areaQueriesFilterAndSort() throws {
        let database = try installDatabase()
        func area(_ id: String, server: String, name: String, order: Int?, entities: Set<String>) -> AppArea {
            AppArea(
                id: "\(server)-\(id)",
                serverId: server,
                areaId: id,
                name: name,
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: order,
                entities: entities
            )
        }
        try database.write { db in
            try area("kitchen", server: "a", name: "Kitchen", order: 2, entities: ["light.k"]).insert(db)
            try area("bath", server: "a", name: "Bath", order: 1, entities: []).insert(db)
            try area("attic", server: "a", name: "Attic", order: nil, entities: ["light.k"]).insert(db)
            try area("zoo", server: "a", name: "zoo", order: nil, entities: []).insert(db)
            try area("garden", server: "b", name: "Garden", order: nil, entities: []).insert(db)
        }

        // swiftformat:disable:next hoistTry
        #expect(try AppArea.fetchAreas(for: "a").map(\.areaId) == ["bath", "kitchen", "attic", "zoo"])
        // swiftformat:disable:next hoistTry
        #expect(try AppArea.fetchAllAreas().count == 5)
        // swiftformat:disable:next hoistTry
        #expect(try AppArea.fetchArea(areaId: "garden", serverId: "b")?.name == "Garden")
        // swiftformat:disable:next hoistTry
        #expect(try AppArea.fetchArea(id: "missing") == nil)
        let containing = try AppArea.fetchAreas(containingEntity: "light.k", serverId: "a").map(\.areaId)
        #expect(containing == ["kitchen", "attic"])
    }

    @Test func areaFromRegistryResponseCarriesItsFields() {
        let response = HAAreasRegistryResponse(
            aliases: ["cook"],
            areaId: "kitchen",
            name: "Kitchen",
            picture: "/pic.png",
            icon: "mdi:stove",
            floorId: "ground"
        )
        let area = AppArea(from: response, serverId: "s", entities: ["light.a"], sortOrder: 3, floorName: "Ground")
        #expect(area.id == "s-kitchen")
        #expect(area.aliases == ["cook"])
        #expect(area.icon == "mdi:stove")
        #expect(area.sortOrder == 3)
        #expect(area.floorName == "Ground")
        #expect(area.entities == ["light.a"])
        #expect(AppArea(from: response, serverId: "s", entities: nil, sortOrder: nil).entities.isEmpty)
    }
}
