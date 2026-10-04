import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// How the widgets read their tiles' states: one `subscribe_entities` batch per server, and one REST
/// request per tile for a server that can't take the batch.
@available(iOS 17, *)
final class WidgetEntityStateProviderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var servers: FakeServerManager!
    private var cacheURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        servers = FakeServerManager()
        Current.servers = servers
        cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheURL)
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        servers = nil
        cacheURL = nil
        super.tearDown()
    }

    /// Every tile of a server comes from the first event of a single subscription, formatted the way
    /// the REST path formats it, and the subscription is dropped once that event is in.
    func testOneSubscriptionReadsEveryTileOfAServer() async throws {
        let (server, connection) = addServer()
        try Current.database().write { db in
            try EntityRegistryListForDisplay.Entity(
                serverId: server.identifier.rawValue,
                entityId: "sensor.temperature",
                decimalPlaces: 1
            ).insert(db)
        }
        let light = item("light.kitchen", on: server)
        let sensor = item("sensor.temperature", on: server)
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: [sensor, light]) }

        let subscription = try await pendingSubscription(on: connection)
        XCTAssertEqual(subscription.request.type, .subscribeEntities)
        XCTAssertEqual(
            subscription.request.data["entity_ids"] as? [String],
            ["light.kitchen", "sensor.temperature"]
        )
        subscription.initiated(.success(.empty))
        subscription.handler(subscription.cancellable, entitiesEvent([
            "light.kitchen": ["s": "on", "a": ["friendly_name": "Kitchen"]],
            "sensor.temperature": ["s": "21.46", "a": ["unit_of_measurement": "°C", "device_class": "temperature"]],
        ]))

        let states = await fetch.value
        XCTAssertEqual(states[light]?.value, "On")
        XCTAssertEqual(states[light]?.rawState, "on")
        XCTAssertEqual(
            states[sensor]?.value,
            "\(StatePrecision.adjustPrecision(stateValue: "21.46", decimalPlaces: 1)) °C"
        )
        XCTAssertEqual(states[sensor]?.deviceClass, "temperature")
        XCTAssertTrue(subscription.cancellable.wasCancelled)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// An entity the server doesn't have is left out of the event, so its tile gets no state, as a
    /// failed REST request would have left it.
    func testEntityMissingFromTheBatchGetsNoState() async throws {
        let (server, connection) = addServer()
        let light = item("light.kitchen", on: server)
        let removed = item("light.removed", on: server)
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: [light, removed]) }

        let subscription = try await pendingSubscription(on: connection)
        subscription.handler(subscription.cancellable, entitiesEvent([
            "light.kitchen": ["s": "off", "a": [String: Any]()],
        ]))

        let states = await fetch.value
        XCTAssertEqual(states[light]?.value, "Off")
        XCTAssertNil(states[removed])
    }

    /// Cores before 2022.4 don't accept `entity_ids`, so their tiles are read over REST.
    func testServerTooOldForTheBatchIsReadOverREST() async throws {
        let (server, connection) = addServer(version: Version(major: 2022, minor: 3))
        let items = [item("light.kitchen", on: server), item("switch.desk", on: server)]
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: items) }

        try await answerStateRequests(on: connection, count: items.count)

        let states = await fetch.value
        XCTAssertEqual(items.map { states[$0]?.value }, ["On", "On"])
        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
    }

    /// A server that refuses the subscription has its tiles read over REST instead, and the refused
    /// subscription is cancelled so HAKit doesn't retry it later.
    func testRefusedSubscriptionFallsBackToREST() async throws {
        let (server, connection) = addServer()
        let items = [item("light.kitchen", on: server), item("switch.desk", on: server)]
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: items) }

        let subscription = try await pendingSubscription(on: connection)
        subscription.initiated(.failure(.external(.init(code: "unknown_command", message: "Unknown command."))))
        try await answerStateRequests(on: connection, count: items.count)

        let states = await fetch.value
        XCTAssertEqual(items.map { states[$0]?.value }, ["On", "On"])
        XCTAssertTrue(subscription.cancellable.wasCancelled)
    }

    /// A websocket already waiting out a reconnect backoff wouldn't carry the subscription in time,
    /// so the batch isn't attempted.
    func testWebsocketInBackoffSkipsTheBatch() async throws {
        let (server, connection) = addServer()
        connection.setState(.disconnected(reason: Self.backoff), waitForQueue: false)
        let items = [item("light.kitchen", on: server)]
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: items) }

        try await answerStateRequests(on: connection, count: items.count)

        let states = await fetch.value
        XCTAssertEqual(states[items[0]]?.value, "On")
        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
    }

    /// A websocket that drops into a reconnect backoff while the subscription is out gives up on it
    /// straight away, leaving the rest of the deadline to the REST fallback.
    func testWebsocketFallingIntoBackoffFallsBackToREST() async throws {
        let (server, connection) = addServer()
        let items = [item("light.kitchen", on: server), item("switch.desk", on: server)]
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: items) }

        let subscription = try await pendingSubscription(on: connection)
        connection.setState(.disconnected(reason: Self.backoff), waitForQueue: false)
        try await answerStateRequests(on: connection, count: items.count)

        let states = await fetch.value
        XCTAssertEqual(items.map { states[$0]?.value }, ["On", "On"])
        XCTAssertTrue(subscription.cancellable.wasCancelled)
    }

    /// Each server is asked on its own connection, and one that can't batch doesn't hold the other
    /// back from doing so.
    func testEachServerIsAskedSeparately() async throws {
        let (current, currentConnection) = addServer(id: "current")
        let (old, oldConnection) = addServer(id: "old", version: Version(major: 2022, minor: 3))
        let currentLight = item("light.kitchen", on: current)
        let oldLight = item("light.kitchen", on: old)
        let provider = stateProvider()

        let fetch = Task { await provider.states(showStates: true, items: [currentLight, oldLight]) }

        let subscription = try await pendingSubscription(on: currentConnection)
        XCTAssertEqual(subscription.request.data["entity_ids"] as? [String], ["light.kitchen"])
        subscription.handler(subscription.cancellable, entitiesEvent([
            "light.kitchen": ["s": "off", "a": [String: Any]()],
        ]))
        try await answerStateRequests(on: oldConnection, count: 1)

        let states = await fetch.value
        XCTAssertEqual(states[currentLight]?.value, "Off")
        XCTAssertEqual(states[oldLight]?.value, "On")
        XCTAssertTrue(oldConnection.pendingSubscriptions.isEmpty)
    }

    /// Tiles of a server the app no longer knows have nothing to be read from.
    func testTilesOfAnUnknownServerGetNoState() async {
        let tile = MagicItem(id: "light.kitchen", serverId: "gone", type: .entity)

        let states = await stateProvider().states(showStates: true, items: [tile])

        XCTAssertTrue(states.isEmpty)
    }

    /// The widgets bound the fetch with a deadline; cancelling the batch must resume it and drop the
    /// subscription rather than leave either hanging.
    func testCancellingTheBatchUnsubscribes() async throws {
        let (server, connection) = addServer()

        let fetch = Task {
            await ControlEntityProvider(domains: []).states(server: server, entityIds: ["light.kitchen"])
        }

        let subscription = try await pendingSubscription(on: connection)
        fetch.cancel()

        let states = await fetch.value
        XCTAssertNil(states)
        XCTAssertTrue(subscription.cancellable.wasCancelled)
    }

    func testBatchesOnlyOverAWebsocketThatCanAnswerInTime() {
        XCTAssertTrue(ControlEntityProvider.canBatchStates(over: .ready(version: "2026.10.0")))
        XCTAssertTrue(ControlEntityProvider.canBatchStates(over: .connecting))
        XCTAssertTrue(ControlEntityProvider.canBatchStates(over: .authenticating))
        XCTAssertTrue(ControlEntityProvider.canBatchStates(over: .disconnected(reason: .disconnected)))
        XCTAssertFalse(ControlEntityProvider.canBatchStates(over: .disconnected(reason: .rejected)))
        XCTAssertFalse(ControlEntityProvider.canBatchStates(over: .disconnected(reason: Self.backoff)))
    }

    // MARK: - Helpers

    private static let backoff: HAConnectionState.DisconnectReason = .waitingToReconnect(
        lastError: nil,
        atLatest: Date(timeIntervalSinceNow: 60),
        retryCount: 2
    )

    /// Adds a server on `version` whose API talks to the returned mock connection.
    private func addServer(
        id: String = "server",
        version: Version = .canSubscribeEntitiesByIds
    ) -> (Server, HAMockConnection) {
        var info = ServerInfo.fake()
        info.version = version
        let server = servers.add(identifier: .init(rawValue: id), serverInfo: info)
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    private func item(_ entityId: String, on server: Server) -> MagicItem {
        MagicItem(id: entityId, serverId: server.identifier.rawValue, type: .entity)
    }

    private func stateProvider() -> WidgetEntityStateProvider {
        let cacheURL = cacheURL!
        return WidgetEntityStateProvider(
            logPrefix: "Test",
            cacheValiditySeconds: 0,
            cacheURL: { cacheURL },
            shouldFetchStates: { true },
            skipFetchLogMessage: nil,
            itemFilter: { _ in true },
            stateValueFormatter: { state, _, _ in
                [state.value, state.unitOfMeasurement].compactMap { $0 }.joined(separator: " ")
            }
        )
    }

    /// The event core sends right after accepting `subscribe_entities`, with every requested entity
    /// in its compressed form.
    private func entitiesEvent(_ entities: [String: [String: Any]]) -> HAData {
        HAData(value: ["a": entities])
    }

    /// The fetch runs off this test's own execution context, so wait for it to reach the mock
    /// connection rather than assuming it has by the time the test looks.
    private func pendingSubscription(
        on connection: HAMockConnection
    ) async throws -> HAMockConnection.PendingSubscription {
        for _ in 0 ..< 200 {
            if let subscription = connection.pendingSubscriptions.first {
                return subscription
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw NeverSent()
    }

    /// Waits for `count` REST `/states` requests and answers each with an entity that is on.
    private func answerStateRequests(on connection: HAMockConnection, count: Int) async throws {
        for _ in 0 ..< 200 {
            if connection.pendingRequests.count >= count {
                for request in connection.pendingRequests {
                    request.completion(.success(HAData(value: ["state": "on", "attributes": [String: Any]()])))
                }
                return
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw NeverSent()
    }

    private struct NeverSent: Error {}
}
