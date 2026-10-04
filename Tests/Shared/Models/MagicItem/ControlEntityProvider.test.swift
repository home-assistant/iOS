import Foundation
import GRDB
import HAKit
@testable import Shared
import XCTest

/// `ControlEntityProvider` against an in-memory database and scripted connections: listing entities
/// per server, and reading an entity's state the ways widgets, controls and complications need it.
final class ControlEntityProviderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var database: DatabaseQueue!
    private var alpha: Server!
    private var beta: Server!
    private var connection: MagicItemTestConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        try SiriServerExposureTable().createIfNeeded(database: database)
        let database = database!
        Current.database = { database }

        let servers = FakeServerManager()
        // Added out of order: entities are listed by server name.
        var betaInfo = ServerInfo.fake()
        betaInfo.remoteName = "Beta"
        beta = servers.add(identifier: .init(rawValue: "B"), serverInfo: betaInfo)
        var alphaInfo = ServerInfo.fake()
        alphaInfo.remoteName = "Alpha"
        alpha = servers.add(identifier: .init(rawValue: "A"), serverInfo: alphaInfo)
        Current.servers = servers

        connection = MagicItemTestConnection()
        let api = HomeAssistantAPI(server: alpha)
        api.connection = connection
        Current.setCachedApi(api, for: alpha.identifier)

        try database.write { db in
            try Self.entity("A", "light.kitchen", name: "Kitchen light").insert(db)
            try Self.entity("A", "switch.porch", name: "Porch").insert(db)
            try Self.entity("A", "sensor.power", name: "Power").insert(db)
            try Self.entity("B", "light.office", name: "Office light").insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: "A",
                entityId: "sensor.power",
                decimalPlaces: 1
            ).insert(db)
        }
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        connection = nil
        alpha = nil
        beta = nil
        database = nil
        super.tearDown()
    }

    private static func entity(_ serverId: String, _ entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: Domain(entityId: entityId)?.rawValue ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }

    private func respond(to entityId: String, with value: [String: Any]) {
        connection.responses["states/\(entityId)"] = .success(.dictionary(value))
    }

    private func respondWithAList(to entityId: String) {
        connection.responses["states/\(entityId)"] = .success(HAData(value: [1, 2]))
    }

    // MARK: - Listing

    func testEntitiesAreListedPerServerInNameOrder() {
        let result = ControlEntityProvider(domains: []).getEntities()

        XCTAssertEqual(result.map(\.0.identifier.rawValue), ["A", "B"])
        XCTAssertEqual(
            Set(result[0].1.map(\.entityId)),
            ["light.kitchen", "switch.porch", "sensor.power"]
        )
        XCTAssertEqual(result[1].1.map(\.entityId), ["light.office"])
    }

    func testEntitiesAreLimitedToTheProvidersDomains() {
        let result = ControlEntityProvider(domains: [.light]).getEntities()

        XCTAssertEqual(result[0].1.map(\.entityId), ["light.kitchen"])
        XCTAssertEqual(result[1].1.map(\.entityId), ["light.office"])
        XCTAssertEqual(ControlEntityProvider(domains: [.light, .switch]).domains, [.light, .switch])
    }

    func testSearchNarrowsTheEntitiesAndABlankQueryDoesNot() {
        let provider = ControlEntityProvider(domains: [])

        let searched = provider.getEntities(matching: "Kitchen")
        XCTAssertEqual(searched[0].1.first?.entityId, "light.kitchen")
        XCTAssertFalse(searched[0].1.contains { $0.entityId == "switch.porch" })

        let blank = provider.getEntities(matching: "   ")
        XCTAssertEqual(blank[0].1.count, 3)
    }

    func testServersHiddenFromSiriAreLeftOut() throws {
        let provider = ControlEntityProvider(domains: [])
        XCTAssertEqual(provider.getEntitiesExposedToSiri().map(\.0.identifier.rawValue), ["A", "B"])

        try database.write { db in
            try SiriServerExposure(serverId: "B", isExposed: false).insert(db)
        }

        XCTAssertEqual(provider.getEntitiesExposedToSiri().map(\.0.identifier.rawValue), ["A"])
        XCTAssertEqual(provider.getEntities().count, 2)
    }

    // MARK: - Reading state

    func testCurrentStateReadsTheStateOverREST() async throws {
        respond(to: "light.kitchen", with: ["state": "on", "attributes": [String: Any]()])
        let provider = ControlEntityProvider(domains: [])

        let state = try await provider.currentState(serverId: "A", entityId: "light.kitchen")
        XCTAssertEqual(state, "on")
        XCTAssertEqual(connection.sentRequests.first?.type, .rest(.get, "states/light.kitchen"))

        let failed = try await provider.currentState(serverId: "A", entityId: "light.missing")
        XCTAssertNil(failed)

        let unknownServer = try await provider.currentState(serverId: "Z", entityId: "light.kitchen")
        XCTAssertNil(unknownServer)
    }

    func testAttributesAreReturnedRaw() async {
        respond(to: "light.kitchen", with: ["state": "on", "attributes": ["brightness": 128]])
        respondWithAList(to: "light.list")
        let provider = ControlEntityProvider(domains: [])

        let attributes = await provider.attributes(server: alpha, entityId: "light.kitchen")
        XCTAssertEqual(attributes?["brightness"] as? Int, 128)

        let notADictionary = await provider.attributes(server: alpha, entityId: "light.list")
        XCTAssertNil(notADictionary)

        let failed = await provider.attributes(server: alpha, entityId: "light.missing")
        XCTAssertNil(failed)
    }

    func testRawStateIsUntouched() async throws {
        respond(to: "sensor.power", with: ["state": "12.345", "attributes": ["unit_of_measurement": "W"]])
        respond(to: "sensor.bare", with: ["state": "3"])
        respond(to: "sensor.stateless", with: ["attributes": [String: Any]()])
        let provider = ControlEntityProvider(domains: [])

        let raw = await provider.rawState(server: alpha, entityId: "sensor.power")
        let power = try XCTUnwrap(raw)
        XCTAssertEqual(power.state, "12.345")
        XCTAssertEqual(power.attributes["unit_of_measurement"] as? String, "W")

        let bare = await provider.rawState(server: alpha, entityId: "sensor.bare")
        XCTAssertEqual(bare?.state, "3")
        XCTAssertEqual(bare?.attributes.isEmpty, true)

        let stateless = await provider.rawState(server: alpha, entityId: "sensor.stateless")
        XCTAssertNil(stateless)

        let failed = await provider.rawState(server: alpha, entityId: "sensor.missing")
        XCTAssertNil(failed)
    }

    func testStateIsFormattedWithTheRegistryPrecisionAndUnit() async throws {
        respond(to: "sensor.power", with: ["state": "12.345", "attributes": ["unit_of_measurement": "W"]])
        let provider = ControlEntityProvider(domains: [])

        let result = await provider.state(server: alpha, entityId: "sensor.power")
        let state = try XCTUnwrap(result)
        XCTAssertEqual(state.value, StatePrecision.adjustPrecision(stateValue: "12.345", decimalPlaces: 1))
        XCTAssertEqual(state.unitOfMeasurement, "W")
        XCTAssertEqual(state.rawState, "12.345")
        XCTAssertNil(state.domainState)
        XCTAssertNil(state.liveColor)
        XCTAssertNil(state.groupMemberDomain)
    }

    func testStateUsesTheDeviceClassWording() async throws {
        connection.respondsAsynchronously = true
        respond(to: "binary_sensor.front_door", with: ["state": "on", "attributes": ["device_class": "door"]])
        let provider = ControlEntityProvider(domains: [])

        let result = await provider.state(server: alpha, entityId: "binary_sensor.front_door")
        let state = try XCTUnwrap(result)
        XCTAssertEqual(state.value, CoreStrings.componentBinarySensorEntityComponentDoorStateOn)
        XCTAssertNil(state.unitOfMeasurement)
        XCTAssertEqual(state.domainState, .on)
        XCTAssertEqual(state.rawState, "on")
        XCTAssertEqual(state.deviceClass, "door")
    }

    func testStateCarriesTheLightColorAndGroupMembers() async throws {
        respond(to: "light.kitchen", with: ["state": "ON", "attributes": ["rgb_color": [255, 120, 0]]])
        respond(to: "group.lights", with: [
            "state": "off",
            "attributes": ["entity_id": ["light.kitchen", "light.office"]],
        ])
        let provider = ControlEntityProvider(domains: [])

        let lightResult = await provider.state(server: alpha, entityId: "light.kitchen")
        let light = try XCTUnwrap(lightResult)
        XCTAssertNotNil(light.liveColor)
        XCTAssertEqual(light.rawState, "on")
        XCTAssertEqual(light.value, "ON")
        XCTAssertEqual(light.domainState, .on)

        let groupResult = await provider.state(server: alpha, entityId: "group.lights")
        let group = try XCTUnwrap(groupResult)
        XCTAssertEqual(group.groupMemberDomain, "light")
        XCTAssertEqual(group.domainState, .off)
        XCTAssertEqual(group.value, "Off")
    }

    func testStateWithoutAValueReadsNotAvailable() async throws {
        respond(to: "sensor.stateless", with: ["attributes": [String: Any]()])
        let provider = ControlEntityProvider(domains: [])

        let result = await provider.state(server: alpha, entityId: "sensor.stateless")
        let state = try XCTUnwrap(result)
        XCTAssertEqual(state.value, "N/A")
        XCTAssertEqual(state.rawState, "n/a")
    }

    func testStateFailuresReadAsNoState() async {
        respondWithAList(to: "sensor.list")
        let provider = ControlEntityProvider(domains: [])

        let notADictionary = await provider.state(server: alpha, entityId: "sensor.list")
        XCTAssertNil(notADictionary)

        let failed = await provider.state(server: alpha, entityId: "sensor.missing")
        XCTAssertNil(failed)

        connection.respondsAsynchronously = true
        let failedLater = await provider.state(server: alpha, entityId: "sensor.missing")
        XCTAssertNil(failedLater)
    }

    func testServerWithoutAURLHasNothingToRead() async {
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
        let provider = ControlEntityProvider(domains: [])

        let state = await provider.state(server: unreachable, entityId: "light.kitchen")
        XCTAssertNil(state)
        let attributes = await provider.attributes(server: unreachable, entityId: "light.kitchen")
        XCTAssertNil(attributes)
        let raw = await provider.rawState(server: unreachable, entityId: "light.kitchen")
        XCTAssertNil(raw)
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }

    func testStateInitializerDefaults() {
        let state = ControlEntityProvider.State(value: "On", unitOfMeasurement: nil, domainState: .on)
        XCTAssertEqual(state.rawState, "")
        XCTAssertNil(state.deviceClass)
        XCTAssertNil(state.liveColor)
        XCTAssertNil(state.groupMemberDomain)
        XCTAssertEqual(ControlEntityProvider.States.closing.rawValue, "closing")
    }
}
