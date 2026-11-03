import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing

/// `AreasService` against a connection that answers each request as it is sent, and an in-memory
/// registry database. Every read of `Current` happens on the test's task, so each test gets its own
/// environment.
@Suite(.isolatedEnvironment)
struct AreasServiceFetchTests {
    private struct Setup {
        let server: Server
        let connection: RespondingHAConnection
        let database: DatabaseQueue
    }

    /// Installs a server whose connection answers every request with what `respond` picks for its
    /// type, so a fetch never waits on a request the test has yet to answer.
    private func setUp(respond: @escaping (HARequestType) -> Result<HAData, HAError>) throws -> Setup {
        let server = Server.fake()
        let api = HomeAssistantAPI(server: server)
        let connection = RespondingHAConnection { respond($0.type) }
        api.connection = connection
        Current.cachedApis[server.identifier] = api

        let database = try DatabaseQueue()
        try database.createSchemaWithPrivateDefaults()
        Current.database = { database }
        return Setup(server: server, connection: connection, database: database)
    }

    private func seedRegistries(_ setup: Setup) throws {
        let serverId = setup.server.identifier.rawValue
        let devices = try [
            DeviceRegistryEntry(data: .dictionary(["id": "hub", "area_id": "kitchen"])),
            DeviceRegistryEntry(data: .dictionary(["id": "sensor", "via_device_id": "hub"])),
        ]
        let entities = try [
            EntityRegistryListForDisplay.Entity(data: .dictionary(["ei": "light.kitchen", "di": "hub"])),
            EntityRegistryListForDisplay.Entity(data: .dictionary(["ei": "light.moved", "di": "hub", "ai": "living"])),
            EntityRegistryListForDisplay.Entity(data: .dictionary(["ei": "sensor.temp", "di": "sensor"])),
        ]
        try setup.database.write { db in
            for device in AppDeviceRegistry.resolvingChildDevices(devices, serverId: serverId) {
                try device.insert(db)
            }
            for var entity in entities {
                entity.serverId = serverId
                try entity.insert(db)
            }
        }
    }

    @Test func areasResolveDirectAndInheritedEntitiesAndFloors() async throws {
        let setup = try setUp { type in
            switch type {
            case .webSocket("config/area_registry/list"):
                return .success(.array([
                    .dictionary(["area_id": "kitchen", "name": "Kitchen", "aliases": [], "floor_id": "ground"]),
                    .dictionary(["area_id": "living", "name": "Living", "aliases": []]),
                ]))
            case .webSocket("config/floor_registry/list"):
                return .success(.array([.dictionary(["floor_id": "ground", "name": "Ground", "aliases": []])]))
            default:
                return .success(.empty)
            }
        }
        try seedRegistries(setup)
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: setup.server)
        #expect(setup.connection.sentCommands == ["config/area_registry/list", "config/floor_registry/list"])
        let serverId = setup.server.identifier.rawValue
        #expect(result["kitchen"]?.contains("light.kitchen") == true)
        #expect(result["kitchen"]?.contains("light.moved") == false)
        #expect(result["living"] == ["light.moved"])
        #expect(service.area(for: "living", serverId: serverId)?.name == "Living")
        #expect(service.area(for: "living", serverId: "other") == nil)
        #expect(service.area(for: "missing", serverId: serverId) == nil)
        #expect(service.floor(for: "ground", serverId: serverId)?.name == "Ground")
        #expect(service.floor(for: "ground", serverId: "other") == nil)
    }

    @Test func areasWithoutFloorsSkipTheFloorRequest() async throws {
        let setup = try setUp { _ in
            .success(.array([.dictionary(["area_id": "office", "name": "Office", "aliases": []])]))
        }
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: setup.server)
        // Nothing in the registry database is in an area, so no area has entities.
        #expect(result.isEmpty)
        #expect(service.areas[setup.server.identifier.rawValue]?.map(\.areaId) == ["office"])
        #expect(setup.connection.sentCommands == ["config/area_registry/list"])
        #expect(service.floors[setup.server.identifier.rawValue]?.isEmpty == true)
    }

    @Test func failedAreaRequestYieldsNothing() async throws {
        let setup = try setUp { _ in
            .failure(.internal(debugDescription: "offline"))
        }
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: setup.server)
        #expect(result.isEmpty)
        #expect(service.areas[setup.server.identifier.rawValue]?.isEmpty == true)
    }
}
