import Foundation
import GRDB
import HAKit
@testable import Shared
import XCTest

/// `AreasService.fetchAreasAndItsEntities` against a scripted connection and an in-memory entity
/// registry: which requests it makes, what it caches, and the area → entities map it returns.
final class AreasServiceFetchTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var connection: MagicItemTestConnection!

    private static let areasCommand = "config/area_registry/list"
    private static let floorsCommand = "config/floor_registry/list"

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        server = Server.fake()
        connection = MagicItemTestConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        let serverId = server.identifier.rawValue
        try database.write { db in
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "light.kitchen",
                areaId: "kitchen"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "sensor.kitchen_temperature",
                areaId: "kitchen"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "light.office",
                areaId: "office"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "sensor.unassigned"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: "other-server",
                entityId: "light.elsewhere",
                areaId: "kitchen"
            ).insert(db)
        }
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.database = previousDatabase
        connection = nil
        server = nil
        super.tearDown()
    }

    private func area(_ areaId: String, name: String, floorId: String? = nil) -> [String: Any] {
        var area: [String: Any] = ["aliases": [String](), "area_id": areaId, "name": name]
        if let floorId {
            area["floor_id"] = floorId
        }
        return area
    }

    func testAreasAreMappedToTheirEntitiesAndFloorsAreFetched() async {
        connection.responses[Self.areasCommand] = .success(HAData(value: [
            area("kitchen", name: "Kitchen", floorId: "ground"),
            area("office", name: "Office"),
        ]))
        let floor: [String: Any] = ["aliases": [String](), "floor_id": "ground", "name": "Ground floor", "level": 0]
        connection.responses[Self.floorsCommand] = .success(HAData(value: [floor]))
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: server)

        XCTAssertEqual(result, [
            "kitchen": ["light.kitchen", "sensor.kitchen_temperature"],
            "office": ["light.office"],
        ])
        let serverId = server.identifier.rawValue
        XCTAssertEqual(service.areas[serverId]?.map(\.areaId), ["kitchen", "office"])
        XCTAssertEqual(service.area(for: "office", serverId: serverId)?.name, "Office")
        XCTAssertNil(service.area(for: "attic", serverId: serverId))
        XCTAssertNil(service.area(for: "office", serverId: "other-server"))
        XCTAssertEqual(service.floor(for: "ground", serverId: serverId)?.name, "Ground floor")
        XCTAssertEqual(
            connection.sentRequests.map(\.type.command),
            [Self.areasCommand, Self.floorsCommand]
        )
    }

    func testFloorsAreSkippedWhenNoAreaHasOne() async {
        connection.responses[Self.areasCommand] = .success(HAData(value: [area("office", name: "Office")]))
        connection.respondsAsynchronously = true
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: server)

        XCTAssertEqual(result, ["office": ["light.office"]])
        XCTAssertEqual(service.floors[server.identifier.rawValue]?.isEmpty, true)
        XCTAssertEqual(connection.sentRequests.map(\.type.command), [Self.areasCommand])
    }

    func testAFailedFloorRequestLeavesNoFloors() async {
        connection.responses[Self.areasCommand] = .success(HAData(value: [
            area("kitchen", name: "Kitchen", floorId: "ground"),
        ]))
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: server)

        XCTAssertEqual(result["kitchen"], ["light.kitchen", "sensor.kitchen_temperature"])
        XCTAssertEqual(service.floors[server.identifier.rawValue]?.isEmpty, true)
    }

    func testNoAreasMeansNothingToMap() async {
        connection.responses[Self.areasCommand] = .success(HAData(value: [Any]()))
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: server)

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(service.areas[server.identifier.rawValue]?.isEmpty, true)
        XCTAssertEqual(service.floors[server.identifier.rawValue]?.isEmpty, true)
    }

    func testAFailedAreaRequestMeansNothingToMap() async {
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: server)

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(service.areas[server.identifier.rawValue]?.isEmpty, true)
    }

    func testServerWithoutAURLIsNotAsked() async {
        let unreachable = Server.fake { info in
            info.connection = ConnectionInfo(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            )
        }
        let service = AreasService()

        let result = await service.fetchAreasAndItsEntities(for: unreachable)

        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(service.areas.isEmpty)
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }
}
