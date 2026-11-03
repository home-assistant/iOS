import Foundation
import GRDB
import HAKit
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import Testing

/// `HACalendarsModel` refreshing from `/states` over a connection that answers each request as it is
/// sent, and reading events through the REST API (stubbed with OHHTTPStubs, which is process-wide),
/// falling back to cached events.
@Suite(.sharedState)
struct HACalendarsModelRefreshTests {
    private static let host = "a6-calendar.example.com"

    /// The answer the connection gives every request (`nil`: the request fails); a test changes it
    /// between refreshes.
    private final class Answer: @unchecked Sendable {
        private let lock = NSLock()
        private var value: HAData?

        var current: HAData? {
            get { lock.lock(); defer { lock.unlock() }; return value }
            set { lock.lock(); value = newValue; lock.unlock() }
        }
    }

    private final class Fixture {
        let servers = FakeServerManager()
        let server: Server
        let answer = Answer()
        let connection: RespondingHAConnection
        let database: DatabaseQueue
        private let previousServers = Current.servers
        private let previousDatabase = Current.database
        private let previousApis = Current.cachedApis

        init() throws {
            self.server = servers.add(
                identifier: .init(rawValue: "calendar-server"),
                serverInfo: with(ServerInfo.fake()) {
                    $0.connection.set(
                        address: URL(string: "http://\(HACalendarsModelRefreshTests.host):8123")!,
                        for: .external
                    )
                }
            )
            Current.servers = servers
            let answer = answer
            self.connection = RespondingHAConnection { _ in
                answer.current.map { .success($0) } ?? .failure(.internal(debugDescription: "offline"))
            }
            let api = HomeAssistantAPI(server: server)
            api.connection = connection
            Current.cachedApis[server.identifier] = api
            database = try DatabaseQueue()
            for table in DatabaseQueue.tables() {
                try table.createIfNeeded(database: database)
            }
            let database = database
            Current.database = { database }
        }

        func restore() {
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.cachedApis = previousApis
        }

        func calendars() throws -> [HACalendar] {
            try database.read { db in try HACalendar.order(Column("sortOrder")).fetchAll(db) }
        }
    }

    private func entity(_ id: String, state: String = "off") -> [String: Any] {
        [
            "entity_id": id,
            "state": state,
            "last_changed": "2026-01-01T00:00:00.000000+00:00",
            "last_updated": "2026-01-01T00:00:00.000000+00:00",
            "attributes": ["friendly_name": id.uppercased()],
            "context": ["id": "c", "user_id": NSNull(), "parent_id": NSNull()],
        ]
    }

    private func refresh(
        _ model: HACalendarsModel,
        _ fixture: Fixture,
        answer: HAData?
    ) async -> Bool {
        fixture.answer.current = answer
        return await model.refresh(server: fixture.server)
    }

    @Test func refreshStoresTheCalendarsFromStates() async throws {
        let fixture = try Fixture()
        defer { fixture.restore() }
        let model = HACalendarsModel()

        let refreshed = await refresh(model, fixture, answer: .array([
            .dictionary(entity("calendar.b")),
            .dictionary(entity("calendar.a", state: "on")),
            .dictionary(entity("calendar.gone", state: "unavailable")),
            .dictionary(entity("sensor.other")),
        ]))
        #expect(refreshed)
        // swiftformat:disable:next hoistTry
        #expect(try fixture.calendars().map(\.entityId) == ["calendar.a", "calendar.b"])

        let failed = await refresh(model, fixture, answer: nil)
        #expect(!failed)
        // swiftformat:disable:next hoistTry
        #expect(try fixture.calendars().count == 2)
    }

    @Test func eventsComeFromTheServerAndFallBackToTheCache() async throws {
        let fixture = try Fixture()
        defer { fixture.restore() }
        let model = HACalendarsModel()
        let calendar = HACalendar(
            id: "calendar-server-calendar.a",
            serverId: fixture.server.identifier.rawValue,
            entityId: "calendar.a",
            name: "A",
            backgroundColor: "#ffffff",
            supportedFeatures: 0,
            sortOrder: 0
        )
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let end = start.addingTimeInterval(7 * 86400)

        let descriptor = stub(condition: isHost(Self.host) && isPath("/api/calendars/calendar.a")) { _ in
            HTTPStubsResponse(jsonObject: [[
                "summary": "Dentist",
                "start": ["dateTime": "2026-06-01T10:00:00+00:00"],
                "end": ["dateTime": "2026-06-01T11:00:00+00:00"],
                "uid": "event-1",
            ]], statusCode: 200, headers: ["Content-Type": "application/json"])
        }
        let live = await model.events(for: calendar, start: start, end: end)
        HTTPStubs.removeStub(descriptor)
        #expect(live.map(\.summary) == ["Dentist"])

        let failing = stub(condition: isHost(Self.host) && isPath("/api/calendars/calendar.a")) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
        }
        let cached = await model.events(for: calendar, start: start, end: end)
        HTTPStubs.removeStub(failing)
        #expect(cached.map(\.summary) == ["Dentist"])

        let orphan = HACalendar(
            id: "x",
            serverId: "unknown-server",
            entityId: "calendar.x",
            name: "X",
            backgroundColor: "#000000",
            supportedFeatures: 0,
            sortOrder: 0
        )
        let orphanEvents = await model.events(for: orphan, start: start, end: end)
        #expect(orphanEvents.isEmpty)
    }
}
