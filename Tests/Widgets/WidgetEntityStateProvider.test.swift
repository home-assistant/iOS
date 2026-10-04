import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import XCTest

/// The state fetcher every list widget shares: when it skips the round trip, when it serves its
/// cache, and how it fills in a tile whose fetch failed from the last states it saved.
@available(iOS 17, *)
final class WidgetEntityStateProviderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousDate: (() -> Date)!
    private var cacheURL: URL!

    private let fixedDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis
        previousDate = Current.date

        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.servers = FakeServerManager()
        Current.date = { [fixedDate] in fixedDate }

        cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-entity-states-\(UUID().uuidString).json")
    }

    override func tearDown() {
        if let cacheURL {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.cachedApis = previousCachedApis
        Current.date = previousDate
        super.tearDown()
    }

    func testStatesDisabledReturnNothingAndWriteNoCache() async {
        let provider = makeProvider()

        let states = await provider.states(showStates: false, items: [Self.item("light.kitchen")])

        XCTAssertTrue(states.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testSkippedFetchReturnsNothing() async {
        let provider = makeProvider(shouldFetchStates: false, skipFetchLogMessage: "Skipping on purpose")

        let states = await provider.states(showStates: true, items: [Self.item("light.kitchen")])

        XCTAssertTrue(states.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testSkippedFetchWithoutMessageReturnsNothing() async {
        let provider = makeProvider(shouldFetchStates: false, skipFetchLogMessage: nil)

        let states = await provider.states(showStates: true, items: [Self.item("light.kitchen")])

        XCTAssertTrue(states.isEmpty)
    }

    /// A cache younger than the validity window is served as it is, without asking any server.
    func testFreshCacheIsServedAsIs() async throws {
        let item = Self.item("light.kitchen")
        try writeCache(createdAt: Date(), states: [item: Self.state("Cached")])
        let provider = makeProvider(cacheValiditySeconds: 600)

        let states = await provider.states(showStates: true, items: [item])

        XCTAssertEqual(states[item]?.value, "Cached")
        XCTAssertEqual(states.count, 1)
    }

    /// A tile whose fetch failed keeps its last known state, and the refreshed cache carries it on.
    func testFailedFetchReusesTheStaleCachedState() async throws {
        let item = Self.item("light.kitchen")
        let other = Self.item("switch.porch")
        try writeCache(
            createdAt: Date(timeIntervalSinceNow: -3600),
            states: [item: Self.state("Stale")]
        )
        let provider = makeProvider(cacheValiditySeconds: 1)

        // No server is registered, so every fetch fails.
        let states = await provider.states(showStates: true, items: [item, other])

        XCTAssertEqual(states[item]?.value, "Stale")
        XCTAssertNil(states[other])

        let rewritten = try readCache()
        XCTAssertEqual(rewritten.cacheCreatedDate, fixedDate)
        XCTAssertEqual(rewritten.states[item]?.value, "Stale")
        XCTAssertEqual(rewritten.states.count, 1)
    }

    /// An unreadable cache is ignored rather than failing the refresh, and gets replaced.
    func testCorruptCacheIsIgnoredAndReplaced() async throws {
        try Data("not json".utf8).write(to: cacheURL)
        let provider = makeProvider()

        let states = await provider.states(showStates: true, items: [Self.item("light.kitchen")])

        XCTAssertTrue(states.isEmpty)
        let rewritten = try readCache()
        XCTAssertTrue(rewritten.states.isEmpty)
        XCTAssertEqual(rewritten.cacheCreatedDate, fixedDate)
    }

    /// Items the filter leaves out are never fetched, so nothing is sent for them.
    func testFilteredOutItemsAreNotFetched() async throws {
        let (server, connection) = connectedServer()
        let script = MagicItem(id: "script.run", serverId: server.identifier.rawValue, type: .script)
        let provider = makeProvider(itemFilter: { $0.type != .script })

        let states = await provider.states(showStates: true, items: [script])

        XCTAssertTrue(states.isEmpty)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// A fetched state goes through the widget's formatter, keeps the raw state for the icon color,
    /// and is saved for the next refresh.
    func testFetchedStateIsFormattedAndCached() async throws {
        let (server, connection) = connectedServer()
        let item = MagicItem(id: "light.kitchen", serverId: server.identifier.rawValue, type: .entity)
        let provider = makeProvider(stateValueFormatter: { state, serverId, entityId in
            "\(state.value)|\(serverId)|\(entityId)"
        })

        let task = Task { await provider.states(showStates: true, items: [item]) }

        let request = try await firstRequest(on: connection)
        request.completion(.success(.init(value: [
            "state": "on",
            "attributes": ["friendly_name": "Kitchen"],
        ])))

        let states = await task.value
        let state = try XCTUnwrap(states[item])
        XCTAssertEqual(state.value.lowercased(), "on|\(server.identifier.rawValue)|light.kitchen".lowercased())
        XCTAssertEqual(state.rawState, "on")
        XCTAssertNil(state.deviceClass)
        XCTAssertNil(state.groupMemberDomain)

        let cached = try readCache()
        XCTAssertEqual(cached.states[item]?.rawState, "on")
    }

    /// A request that fails leaves the tile without a state when there is nothing cached for it.
    func testFailedRequestWithoutCacheLeavesTheTileEmpty() async throws {
        let (server, connection) = connectedServer()
        let item = MagicItem(id: "light.kitchen", serverId: server.identifier.rawValue, type: .entity)
        let provider = makeProvider()

        let task = Task { await provider.states(showStates: true, items: [item]) }

        let request = try await firstRequest(on: connection)
        request.completion(.failure(.internal(debugDescription: "unreachable")))

        let states = await task.value
        XCTAssertNil(states[item])
    }

    func testCustomColorWinsOverTheStatePalette() {
        let state = Self.state("On")

        XCTAssertEqual(state.iconColor(domain: .light, customColor: .purple), .purple)
        XCTAssertEqual(
            state.iconColor(domain: .light),
            EntityIconColorProvider.iconColor(domain: "light", deviceClass: nil, state: "on")
        )
        XCTAssertEqual(
            state.iconColor(domain: nil),
            EntityIconColorProvider.iconColor(domain: "", deviceClass: nil, state: "on")
        )
    }

    // MARK: - Helpers

    private func makeProvider(
        cacheValiditySeconds: TimeInterval = 1,
        shouldFetchStates: Bool = true,
        skipFetchLogMessage: String? = nil,
        itemFilter: @escaping (MagicItem) -> Bool = { _ in true },
        stateValueFormatter: @escaping (ControlEntityProvider.State, String, String) -> String = { state, _, _ in
            state.value
        }
    ) -> WidgetEntityStateProvider {
        let url = cacheURL!
        return WidgetEntityStateProvider(
            logPrefix: "Test",
            cacheValiditySeconds: cacheValiditySeconds,
            cacheURL: { url },
            shouldFetchStates: { shouldFetchStates },
            skipFetchLogMessage: skipFetchLogMessage,
            itemFilter: itemFilter,
            stateValueFormatter: stateValueFormatter
        )
    }

    private func connectedServer() -> (Server, HAMockConnection) {
        let servers = FakeServerManager()
        let server = servers.addFake()
        Current.servers = servers
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    private func writeCache(createdAt: Date, states: [MagicItem: WidgetEntityState]) throws {
        let data = try JSONEncoder().encode(WidgetEntitiesStateCache(cacheCreatedDate: createdAt, states: states))
        try data.write(to: cacheURL)
    }

    private func readCache() throws -> WidgetEntitiesStateCache {
        try JSONDecoder().decode(WidgetEntitiesStateCache.self, from: Data(contentsOf: cacheURL))
    }

    private static func item(_ entityId: String) -> MagicItem {
        MagicItem(id: entityId, serverId: "unknown-server", type: .entity)
    }

    private static func state(_ value: String) -> WidgetEntityState {
        WidgetEntityState(
            value: value,
            domainState: nil,
            rawState: "on",
            deviceClass: nil,
            liveColorHex: nil,
            groupMemberDomain: nil
        )
    }

    /// The fetch runs off this test's own execution context, so wait for the request to reach the
    /// mock connection rather than assuming it has been sent by the time the test looks.
    private func firstRequest(on connection: HAMockConnection) async throws -> HAMockConnection.PendingRequest {
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
