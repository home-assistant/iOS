import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The value the Details and Gauge widgets show for a picked entity, resolved against a mock
/// connection and an in-memory copy of the entity registry that carries the display precision.
final class WidgetEntityAttributesTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database

        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api

        try database.write { db in
            try EntityRegistryListForDisplay.Entity(
                serverId: server.identifier.rawValue,
                entityId: "climate.living_room",
                decimalPlaces: 1
            ).insert(db)
        }
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.database = previousDatabase
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    /// A unit-converted temperature attribute carries floating point noise; the registry precision
    /// rounds it the way the frontend does, and the sibling `_unit` attribute supplies the unit.
    func testAttributeValueIsRoundedToTheRegistryPrecision() async throws {
        let task = Task { [server] in
            await WidgetEntityAttributes.resolvedValue(
                entityId: "climate.living_room",
                attribute: "current_temperature",
                server: server!
            )
        }

        let request = try await stateRequest()
        request.completion(.success(.init(value: [
            "state": "heat",
            "attributes": [
                "current_temperature": 78.99999999999999,
                "current_temperature_unit": "°F",
            ],
        ])))

        let value = await task.value
        let resolved = try XCTUnwrap(value)
        XCTAssertEqual(
            resolved.value,
            StatePrecision.adjustPrecision(stateValue: "78.99999999999999", decimalPlaces: 1)
        )
        XCTAssertFalse(resolved.value.contains("9999"))
        XCTAssertEqual(resolved.unit, "°F")
    }

    /// A non-numeric attribute has nothing to round and passes through as the server sent it.
    func testNonNumericAttributeValuePassesThrough() async throws {
        let task = Task { [server] in
            await WidgetEntityAttributes.resolvedValue(
                entityId: "climate.living_room",
                attribute: "hvac_action",
                server: server!
            )
        }

        let request = try await stateRequest()
        request.completion(.success(.init(value: [
            "state": "heat",
            "attributes": ["hvac_action": "heating"],
        ])))

        let value = await task.value
        let resolved = try XCTUnwrap(value)
        XCTAssertEqual(resolved.value, "heating")
        XCTAssertNil(resolved.unit)
    }

    /// The resolver runs off this test's own execution context, so wait for the `/states` request to
    /// reach the mock connection rather than assuming it has been sent by the time the test looks.
    private func stateRequest() async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 200 {
            if let pending = connection.pendingRequests.first {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw StateRequestNeverSent()
    }

    private struct StateRequestNeverSent: Error {}
}
