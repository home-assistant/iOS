import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Builds the Entities menu tree from the database: one server per entry, areas grouped by floor
/// with the floorless ones last, devices and their entities inside, and an empty tree for a server
/// whose data can't be read.
///
/// `.isolatedEnvironment`: `loadServers()` reads `Current.servers` and `Current.database` on the
/// calling task.
@Suite(.isolatedEnvironment)
struct MainWindowGroupCommandsDataSourceTests {
    private func area(
        _ name: String,
        serverId: String,
        floorId: String? = nil,
        floorName: String? = nil,
        entities: Set<String>
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(name)",
            serverId: serverId,
            areaId: name,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities,
            floorId: floorId,
            floorName: floorName
        )
    }

    @Test func groupsAreasByFloorWithTheirDevicesAndEntities() throws {
        let manager = FakeServerManager(initial: 2)
        Current.servers = manager
        let serverId = manager.all[0].identifier.rawValue
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            try area("Kitchen", serverId: serverId, floorId: "ground", floorName: "Ground", entities: [
                "light.kitchen", "sensor.kitchen_temperature",
            ]).insert(db)
            try area("Attic", serverId: serverId, floorId: "top", floorName: "Attic floor", entities: [
                "fan.attic",
            ]).insert(db)
            try area("Garden", serverId: serverId, entities: ["switch.sprinkler"]).insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: "Kitchen",
                deviceId: "kitchen_light",
                serverId: serverId,
                name: "Kitchen light"
            ).insert(db)
            for entity in [
                EntityRegistryListForDisplay.Entity(
                    serverId: serverId,
                    entityId: "light.kitchen",
                    deviceId: "kitchen_light",
                    name: "Ceiling"
                ),
                EntityRegistryListForDisplay.Entity(
                    serverId: serverId,
                    entityId: "sensor.kitchen_temperature",
                    name: "Temperature"
                ),
                EntityRegistryListForDisplay.Entity(serverId: serverId, entityId: "fan.attic", name: "Fan"),
                EntityRegistryListForDisplay.Entity(
                    serverId: serverId,
                    entityId: "switch.sprinkler",
                    name: "Sprinkler"
                ),
            ] {
                try entity.insert(db)
            }
        }
        Current.database = { database }

        let servers = MainWindowGroupCommands.DataSource.loadServers()

        #expect(servers.map(\.id) == manager.all.map(\.identifier.rawValue))
        let first = try #require(servers.first)
        // Named floors sorted by name, the floorless group last.
        #expect(first.floors.map(\.name) == ["Attic floor", "Ground", L10n.MainWindowGroupCommands.Floor.empty])
        #expect(first.floors.last?.id == "no-floor")
        let kitchen = try #require(first.floors.first { $0.id == "ground" }?.areas.first)
        #expect(kitchen.name == "Kitchen")
        #expect(kitchen.devices.contains { $0.name == "Kitchen light" })
        let entityIds = kitchen.devices.flatMap { $0.domains.flatMap { $0.entities.map(\.entityId) } }
        #expect(Set(entityIds) == ["light.kitchen", "sensor.kitchen_temperature"])
        // The second server has no areas.
        #expect(servers.last?.floors.isEmpty == true)
    }

    @Test func aServerWhoseDataCantBeReadGetsAnEmptyTree() throws {
        let manager = FakeServerManager(initial: 1)
        Current.servers = manager
        // No tables: every query fails.
        let database = try DatabaseQueue()
        Current.database = { database }

        let servers = MainWindowGroupCommands.DataSource.loadServers()

        #expect(servers.count == 1)
        #expect(servers.first?.name == manager.all[0].info.name)
        #expect(servers.first?.floors.isEmpty == true)
    }

    @Test func floorsSortByNameWithTheFloorlessGroupLast() {
        let areas = [
            MainWindowGroupCommands.AreasCommandArea(id: "a", name: "A", floorId: nil, floorName: nil, devices: []),
            MainWindowGroupCommands.AreasCommandArea(id: "b", name: "B", floorId: "2", floorName: "beta", devices: []),
            MainWindowGroupCommands.AreasCommandArea(id: "c", name: "C", floorId: "1", floorName: "Alpha", devices: []),
            MainWindowGroupCommands.AreasCommandArea(id: "d", name: "D", floorId: "1", floorName: "Alpha", devices: []),
        ]

        let floors = MainWindowGroupCommands.DataSource.floors(from: areas)

        #expect(floors.map(\.id) == ["1", "2", "no-floor"])
        #expect(floors.first?.areas.count == 2)
    }

    @Test func theDataSourceStaysEmptyWithoutAMenuBar() {
        let source = MainWindowGroupCommands.DataSource(notificationCenter: NotificationCenter())
        if !Current.isCatalyst, UIDevice.current.userInterfaceIdiom != .pad {
            #expect(source.servers.isEmpty)
        }
    }
}
