import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared

/// A server with a mock websocket, an in-memory database holding a few calendars, a stubbed
/// `/api/calendars` REST endpoint and a scripted calendars model, installed into the global
/// `Current` for the length of `run`. Callers must be `.sharedState` suites.
@MainActor
final class CalendarTestWorld {
    let server: Server
    let connection = HAMockConnection()
    let database: DatabaseQueue
    let model = ScriptedCalendarsModel()

    /// Creates, deletes and updates events; reads and edits nothing else.
    lazy var writable = calendar(entityId: "calendar.family", name: "Family", features: 7)
    /// Read-only: an integration that cannot change events.
    lazy var readOnly = calendar(entityId: "calendar.holidays", name: "Holidays", features: 0)

    init() throws {
        self.server = Server.fake()
        self.database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
    }

    func calendar(entityId: String, name: String, features: Int) -> HACalendar {
        HACalendar(
            id: "\(server.identifier.rawValue)-\(entityId)",
            serverId: server.identifier.rawValue,
            entityId: entityId,
            name: name,
            backgroundColor: "#4269d0",
            supportedFeatures: features,
            sortOrder: 0
        )
    }

    /// Answers the first pending websocket command once it arrives.
    func answerNextCommand(with result: Result<HAData, HAError> = .success(.empty)) async -> HARequest? {
        let deadline = Date().addingTimeInterval(10)
        while connection.pendingRequests.isEmpty {
            if Date() > deadline { return nil }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let request = connection.pendingRequests.removeFirst()
        request.completion(result)
        return request.request
    }

    static func eventsJSON(day: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let next = calendar.date(byAdding: .day, value: 1, to: start)!
        return """
        [{"summary": "Bins", "start": {"date": "\(dayFormatter.string(from: start))"},
          "end": {"date": "\(dayFormatter.string(from: next))"}, "location": "Street",
          "description": "Recycling", "uid": "bins"},
         {"summary": "Meeting", "start": {"dateTime": "\(formatter.string(from: start.addingTimeInterval(9 * 3600)))"},
          "end": {"dateTime": "\(formatter.string(from: start.addingTimeInterval(10 * 3600)))"},
          "uid": "meeting", "recurrence_id": "20261030", "rrule": "FREQ=WEEKLY"},
         {"summary": "Instant", "start": "\(formatter.string(from: start.addingTimeInterval(12 * 3600)))",
          "end": "\(formatter.string(from: start.addingTimeInterval(12 * 3600)))"}]
        """
    }

    func run(eventsStatus: Int32 = 200, _ body: () async throws -> Void) async throws {
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        let servers = FakeServerManager()
        servers.add(identifier: server.identifier, serverInfo: server.info)
        let calendars = [writable, readOnly]
        try await database.write { db in
            for calendar in calendars {
                try calendar.insert(db)
            }
        }
        let json = Self.eventsJSON()
        let descriptor = stub(
            condition: { $0.url?.path.hasPrefix("/api/calendars/") == true },
            response: { _ in .init(data: Data(json.utf8), statusCode: eventsStatus, headers: nil) }
        )

        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousModel = Current.calendarsModel
        let database = database
        let model = model
        Current.servers = servers
        Current.setCachedApi(api, for: server.identifier)
        Current.database = { database }
        Current.calendarsModel = { model }
        defer {
            HTTPStubs.removeStub(descriptor)
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.calendarsModel = previousModel
        }
        try await body()
    }
}

/// Hands back the events it was given and records what it was asked. A query asks for the events of several
/// calendars from concurrent child tasks, so every member is guarded by a lock.
final class ScriptedCalendarsModel: HACalendarsModelProtocol {
    private let lock = NSLock()
    private var storedEvents: [HACalendarEvent] = []
    private var storedRefreshSucceeds = true
    private var storedRefreshed: [String] = []
    private var storedAsked: [String] = []

    var events: [HACalendarEvent] {
        get { lock.withLock { storedEvents } }
        set { lock.withLock { storedEvents = newValue } }
    }

    var refreshSucceeds: Bool {
        get { lock.withLock { storedRefreshSucceeds } }
        set { lock.withLock { storedRefreshSucceeds = newValue } }
    }

    var refreshed: [String] {
        lock.withLock { storedRefreshed }
    }

    var asked: [String] {
        lock.withLock { storedAsked }
    }

    func updateModel(_ entities: [HAEntity], server: Server) async {}

    func refresh(server: Server) async -> Bool {
        lock.withLock {
            storedRefreshed.append(server.identifier.rawValue)
            return storedRefreshSucceeds
        }
    }

    func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
        lock.withLock {
            storedAsked.append(calendar.entityId)
            return storedEvents
        }
    }
}
