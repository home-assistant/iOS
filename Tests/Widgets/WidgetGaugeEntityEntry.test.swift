import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The Gauge widget's entity source beyond the happy path, plus the intent's own surface: the
/// gallery sample, the gauge types and the parameter summary the Shortcuts editor draws.
@available(iOS 17, *)
final class WidgetGaugeEntityEntryTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
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
        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        connection = nil
        server = nil
        super.tearDown()
    }

    func testNoEntityThrows() async {
        let configuration = WidgetGaugeAppIntent()
        configuration.server = .init(identifier: server.identifier)

        do {
            _ = try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration)
            XCTFail("Expected noEntity")
        } catch {
            XCTAssertEqual(error as? WidgetGaugeDataError, .noEntity)
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// The single-label gauge carries the entity's name as its label, no bounds, and a value above
    /// the range fills the gauge rather than overflowing it.
    func testSingleLabelGaugeClampsAndLabelsWithTheEntityName() async throws {
        let configuration = makeConfiguration(entityId: "sensor.power", gaugeType: .singleLabel)
        configuration.minValue = 0
        configuration.maxValue = 100
        configuration.runScript = true
        configuration.showConfirmationNotification = false

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        try await respond(with: ["state": "150", "attributes": [String: Any]()])

        let entry = try await task.value
        XCTAssertEqual(entry.gaugeType, .singleLabel)
        XCTAssertEqual(entry.value, 1)
        XCTAssertEqual(entry.valueLabel, "150")
        XCTAssertEqual(entry.label, "Power")
        XCTAssertNil(entry.min)
        XCTAssertNil(entry.max)
        XCTAssertTrue(entry.runScript)
        XCTAssertFalse(entry.showConfirmationNotification)
        XCTAssertNil(entry.complicationModel)
    }

    /// A value below the range empties the gauge, and fractional bounds are labelled as they are.
    func testNormalGaugeBelowRangeAndFractionalBounds() async throws {
        let configuration = makeConfiguration(entityId: "sensor.level", gaugeType: .normal)
        configuration.minValue = 0.5
        configuration.maxValue = 10

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        try await respond(with: ["state": "0", "attributes": ["unit_of_measurement": "m"]])

        let entry = try await task.value
        XCTAssertEqual(entry.value, 0)
        XCTAssertEqual(entry.valueLabel, "0 m")
        XCTAssertEqual(entry.min, "0.5")
        XCTAssertEqual(entry.max, "10")
        XCTAssertNil(entry.label)
    }

    /// An empty range can't be mapped, and a state that isn't a number has nothing to map, so the
    /// capacity gauge stays empty in both cases.
    func testCapacityGaugeWithAnEmptyRangeStaysEmpty() async throws {
        let configuration = makeConfiguration(entityId: "sensor.mode", gaugeType: .capacity)
        configuration.minValue = 10
        configuration.maxValue = 10

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        try await respond(with: ["state": "eco", "attributes": [String: Any]()])

        let entry = try await task.value
        XCTAssertEqual(entry.gaugeType, .capacity)
        XCTAssertEqual(entry.value, 0)
        XCTAssertEqual(entry.valueLabel?.lowercased(), "eco")
        XCTAssertNil(entry.min)
        XCTAssertNil(entry.max)
        XCTAssertNil(entry.label)
    }

    /// With an attribute picked, the gauge reads that attribute instead of the state.
    func testAttributeDrivesTheGauge() async throws {
        let configuration = makeConfiguration(entityId: "vacuum.robot", gaugeType: .normal)
        configuration.attribute = WidgetGaugeAttributeAppEntity(id: "battery_level")
        configuration.minValue = 0
        configuration.maxValue = 100

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        try await respond(with: ["state": "docked", "attributes": ["battery_level": 40]])

        let entry = try await task.value
        XCTAssertEqual(entry.value, 0.4, accuracy: 0.0001)
        XCTAssertTrue(entry.valueLabel?.hasPrefix("40") == true)
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testFailedStateRequestThrowsApiError() async throws {
        let configuration = makeConfiguration(entityId: "sensor.power", gaugeType: .normal)

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        let request = try await firstRequest()
        request.completion(.failure(.internal(debugDescription: "offline")))

        do {
            _ = try await task.value
            XCTFail("Expected apiError")
        } catch {
            XCTAssertEqual(error as? WidgetGaugeDataError, .apiError)
        }
    }

    /// An entity whose server is no longer known is read from the configured server instead.
    func testUnknownEntityServerFallsBackToTheConfiguredServer() async throws {
        let configuration = makeConfiguration(entityId: "sensor.power", gaugeType: .normal, serverId: "gone")

        let task = Task { try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration) }
        try await respond(with: ["state": "50", "attributes": [String: Any]()])

        let entry = try await task.value
        XCTAssertEqual(entry.value, 0.5, accuracy: 0.0001)
        XCTAssertEqual(entry.min, "0")
        XCTAssertEqual(entry.max, "100")
    }

    func testNoServersThrows() async {
        Current.servers = FakeServerManager()
        let configuration = WidgetGaugeAppIntent()
        configuration.server = .init(identifier: .init(rawValue: "gone"))
        configuration.entity = Self.entity(entityId: "sensor.power", serverId: "gone")

        do {
            _ = try await WidgetGaugeAppIntentTimelineProvider().entityEntry(for: configuration)
            XCTFail("Expected noServers")
        } catch {
            XCTAssertEqual(error as? WidgetGaugeDataError, .noServers)
        }
    }

    func testPreviewSampleFollowsTheConfiguration() {
        let configuration = WidgetGaugeAppIntent()
        configuration.gaugeType = .capacity
        configuration.showConfirmationNotification = false

        let sample = WidgetGaugeAppIntentTimelineProvider.previewSample(for: configuration)

        XCTAssertEqual(sample.gaugeType, .capacity)
        XCTAssertFalse(sample.showConfirmationNotification)
        XCTAssertEqual(sample.value, 0.67)
        XCTAssertEqual(sample.valueLabel, "67%")
        XCTAssertEqual(sample.min, "0")
        XCTAssertEqual(sample.max, "100")
        XCTAssertFalse(sample.runScript)
        XCTAssertNil(sample.script)

        let defaults = WidgetGaugeAppIntentTimelineProvider.previewSample()
        XCTAssertEqual(defaults.gaugeType, .normal)
        XCTAssertTrue(defaults.showConfirmationNotification)
    }

    func testExpirationIsFifteenMinutes() {
        XCTAssertEqual(WidgetGaugeDataSource.expiration.converted(to: .seconds).value, 15 * 60)
    }

    func testGaugeTypesAllHaveADisplayRepresentation() {
        let gaugeTypes: [GaugeTypeAppEnum] = [.normal, .singleLabel, .capacity]
        XCTAssertEqual(GaugeTypeAppEnum.caseDisplayRepresentations.count, gaugeTypes.count)
        for gaugeType in gaugeTypes {
            XCTAssertNotNil(GaugeTypeAppEnum.caseDisplayRepresentations[gaugeType])
        }
        XCTAssertEqual(GaugeTypeAppEnum(rawValue: "singleLabel"), .singleLabel)
    }

    func testAttributeEntityQueryMapsIdentifiers() async throws {
        let entities = try await WidgetGaugeAttributeAppEntityQuery().entities(for: ["battery", "temperature"])

        XCTAssertEqual(entities.map(\.id), ["battery", "temperature"])
        XCTAssertEqual(WidgetGaugeAttributeAppEntity(id: "battery").id, "battery")
        _ = WidgetGaugeAttributeAppEntity(id: "battery").displayRepresentation
    }

    func testParameterSummaryBuilds() {
        XCTAssertFalse(String(describing: WidgetGaugeAppIntent.parameterSummary).isEmpty)
    }

    // MARK: - Helpers

    private func makeConfiguration(
        entityId: String,
        gaugeType: GaugeTypeAppEnum,
        serverId: String? = nil
    ) -> WidgetGaugeAppIntent {
        let configuration = WidgetGaugeAppIntent()
        configuration.server = .init(identifier: server.identifier)
        configuration.entity = Self.entity(entityId: entityId, serverId: serverId ?? server.identifier.rawValue)
        configuration.gaugeType = gaugeType
        configuration.minValue = 0
        configuration.maxValue = 100
        return configuration
    }

    private static func entity(entityId: String, serverId: String) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            serverName: "Home",
            displayString: "Power",
            iconName: "bolt"
        )
    }

    private func respond(with value: [String: Any]) async throws {
        let request = try await firstRequest()
        request.completion(.success(.init(value: value)))
    }

    /// The provider runs off this test's own execution context, so wait for the `/states` request to
    /// reach the mock connection rather than assuming it has been sent by the time the test looks.
    private func firstRequest() async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 300 {
            if let pending = connection.pendingRequests.first {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent()
    }

    private struct RequestNeverSent: Error {}
}
