import GRDB
import HAKit
import HAKit_Mocks
@testable import Shared
import XCTest

/// The refresh half of the most-used-entities cache: what the backend answers, what is kept, and
/// what the app falls back on when the server cannot be reached.
final class EntityUsageProviderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var connection: HAMockConnection!

    /// A fixed moment. Which bucket it falls in depends on the machine's time zone, so every
    /// assertion about the bucket derives it the same way the provider does.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        let database = try DatabaseQueue(path: ":memory:")
        try EntityUsageRecordTable().createIfNeeded(database: database)
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

    /// The backend's answer is both returned to the caller and filed under the bucket for the time
    /// of day it was asked in, in the order it came back.
    func testSuccessfulRefreshIsReturnedAndCached() async throws {
        let task = Task { await EntityUsageProvider().refresh(for: server, now: now) }

        let request = try await pendingRequest()
        request.completion(.success(.init(value: [
            "entities": ["light.kitchen", "switch.porch"],
        ])))

        let entities = await task.value
        XCTAssertEqual(entities, ["light.kitchen", "switch.porch"])

        let cached = EntityUsageRecord.all(serverId: server.identifier.rawValue)
        XCTAssertEqual(cached.map(\.entityId).sorted(), ["light.kitchen", "switch.porch"])
        XCTAssertEqual(Set(cached.map(\.timeCategory)), [EntityUsageTimeCategory.forDate(now).rawValue])
        XCTAssertEqual(cached.first { $0.entityId == "light.kitchen" }?.rank, 0)
        XCTAssertEqual(cached.first { $0.entityId == "switch.porch" }?.rank, 1)
    }

    /// A server that cannot be reached says nothing about what the user uses: the cache is left
    /// alone and answers in its place, so a widget keeps its tiles instead of emptying out.
    func testFailedRefreshFallsBackToTheCacheAndKeepsIt() async throws {
        EntityUsageRecord.save(
            entityIds: ["light.hall"],
            serverId: server.identifier.rawValue,
            timeCategory: EntityUsageTimeCategory.forDate(now),
            now: now
        )

        let task = Task { await EntityUsageProvider().refresh(for: server, now: now) }

        let request = try await pendingRequest()
        request.completion(.failure(.internal(debugDescription: "offline")))

        let entities = await task.value
        XCTAssertEqual(entities, ["light.hall"])
        XCTAssertEqual(EntityUsageRecord.all(serverId: server.identifier.rawValue).map(\.entityId), ["light.hall"])
    }

    /// The provider runs off this test's own execution context, so wait for the request to reach the
    /// mock connection rather than assuming it has been sent by the time the test looks.
    private func pendingRequest() async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 200 {
            if let pending = connection.pendingRequests.first {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent()
    }

    private struct RequestNeverSent: Error {}
}
