import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The gauge the Gauge widget builds from a picked entity, resolved against a mock connection and
/// an in-memory copy of the entity registry that carries the display precision.
@available(iOS 17, *)
final class WidgetGaugeAppIntentTimelineProviderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        try database.write { db in
            try EntityRegistryListForDisplay.Entity(
                serverId: server.identifier.rawValue,
                entityId: "sensor.energy",
                decimalPlaces: 1
            ).insert(db)
        }
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    /// The fill maps the number behind the state onto the configured range, even once the label has
    /// been rounded and grouped for display (`1,234.5 kWh`), which is no longer parseable as a number.
    func testEntityGaugeFillsFromTheRawNumberAndLabelsWithTheRoundedValue() async throws {
        let configuration = WidgetGaugeAppIntent()
        configuration.server = .init(identifier: server.identifier)
        configuration.entity = HAAppEntityAppIntentEntity(
            id: "\(server.identifier.rawValue)-sensor.energy",
            entityId: "sensor.energy",
            serverId: server.identifier.rawValue,
            serverName: server.info.name,
            displayString: "Energy",
            iconName: "bolt"
        )
        configuration.gaugeType = .normal
        configuration.minValue = 0
        configuration.maxValue = 2000

        let task = Task {
            try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration)
        }

        let request = try await stateRequest()
        request.completion(.success(.init(value: [
            "state": "1234.5",
            "attributes": ["unit_of_measurement": "kWh"],
        ])))

        let entry = try await task.value
        XCTAssertEqual(entry.value, 1234.5 / 2000, accuracy: 0.0001)
        XCTAssertEqual(
            entry.valueLabel,
            "\(StatePrecision.adjustPrecision(stateValue: "1234.5", decimalPlaces: 1)) kWh"
        )
        XCTAssertEqual(entry.min, "0")
        XCTAssertEqual(entry.max, "2000")
    }

    /// The provider runs off this test's own execution context, so wait for the `/states` request to
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
