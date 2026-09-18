import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The world the App Intents schema types run in: an in-memory database, one fake server, and a
/// mock connection standing in for it.
///
/// Every schema type reads the database or reaches the server through `Current`, so each test gets
/// its own copy of both and puts the globals back afterwards. iOS 27 across the board, because the
/// schema domains these types conform to only exist there.
@available(iOS 27.0, *)
class AppIntentSchemaTestCase: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousRefreshNetworkInformation: (() async -> Void)!
    private var previousCalendarsModel: (() -> HACalendarsModelProtocol)!

    var database: DatabaseQueue!
    var servers: FakeServerManager!
    var server: Server!
    var connection: HAMockConnection!
    var calendarsModel: FakeCalendarsModel!

    var serverId: String { server.identifier.rawValue }

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        previousCalendarsModel = Current.calendarsModel
        // Nothing here talks to a network; the real one waits on the SSID lookup.
        Current.connectivity.refreshNetworkInformation = {}

        let database = try DatabaseQueue(path: ":memory:")
        try SiriServerExposureTable().createIfNeeded(database: database)
        try SiriEntityExposureTable().createIfNeeded(database: database)
        try HACalendarTable().createIfNeeded(database: database)
        try HACalendarEventTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }

        servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        let calendarsModel = FakeCalendarsModel()
        self.calendarsModel = calendarsModel
        Current.calendarsModel = { calendarsModel }
    }

    override func tearDown() {
        Current.calendarsModel = previousCalendarsModel
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        calendarsModel = nil
        connection = nil
        server = nil
        servers = nil
        database = nil
        super.tearDown()
    }

    // MARK: - Seeding

    /// Opts a server out of Siri, the way the setting's row reads.
    func hideFromSiri(_ serverId: String) throws {
        try database.write { db in
            try SiriServerExposure(serverId: serverId, isExposed: false).insert(db)
        }
    }

    func hideEntityFromSiri(_ entityId: String, domain: String, onServer serverId: String? = nil) throws {
        try database.write { db in
            try SiriEntityExposure(
                serverId: serverId ?? self.serverId,
                entityId: entityId,
                domain: domain,
                isExposed: false,
                isDefault: false
            ).insert(db)
        }
    }

    func makeSiriDefault(_ entityId: String, domain: String, onServer serverId: String? = nil) throws {
        try database.write { db in
            try SiriEntityExposure(
                serverId: serverId ?? self.serverId,
                entityId: entityId,
                domain: domain,
                isExposed: true,
                isDefault: true
            ).insert(db)
        }
    }

    @discardableResult
    func seedCalendar(
        entityId: String = "calendar.home",
        name: String = "Home",
        supportedFeatures: Int = 7,
        onServer serverId: String? = nil,
        sortOrder: Int = 0
    ) throws -> HACalendar {
        let owner = serverId ?? self.serverId
        let calendar = HACalendar(
            id: "\(owner)-\(entityId)",
            serverId: owner,
            entityId: entityId,
            name: name,
            backgroundColor: "#4269d0",
            supportedFeatures: supportedFeatures,
            sortOrder: sortOrder
        )
        try database.write { try calendar.insert($0) }
        return calendar
    }

    @discardableResult
    func seedEvent(
        id: String = "event-1",
        calendarEntityId: String = "calendar.home",
        uid: String? = "uid-1",
        recurrenceId: String? = nil,
        summary: String = "Dentist",
        start: Date = Date(timeIntervalSince1970: 1_700_000_000),
        end: Date = Date(timeIntervalSince1970: 1_700_003_600),
        isAllDay: Bool = false,
        eventDescription: String? = nil,
        location: String? = nil,
        onServer serverId: String? = nil
    ) throws -> HACalendarEventRecord {
        let record = HACalendarEventRecord(
            id: id,
            serverId: serverId ?? self.serverId,
            calendarEntityId: calendarEntityId,
            uid: uid,
            recurrenceId: recurrenceId,
            summary: summary,
            start: start,
            end: end,
            isAllDay: isAllDay,
            eventDescription: eventDescription,
            location: location,
            rrule: nil
        )
        try database.write { try record.insert($0) }
        return record
    }

    @discardableResult
    func seedTodoList(
        entityId: String = "todo.shopping",
        name: String = "Shopping",
        onServer serverId: String? = nil
    ) throws -> HAAppEntity {
        let owner = serverId ?? self.serverId
        let entity = HAAppEntity(
            id: ServerEntity.uniqueId(serverId: owner, entityId: entityId),
            entityId: entityId,
            serverId: owner,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: nil
        )
        try database.write { try entity.insert($0) }
        return entity
    }

    // MARK: - Driving the mock connection

    /// The request at `index`, once it has been sent.
    ///
    /// An intent runs off this test's own execution context, so the request has to be waited for
    /// rather than assumed to have arrived by the time the test looks.
    func request(at index: Int = 0) async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 300 {
            if connection.pendingRequests.count > index {
                return connection.pendingRequests[index]
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent(index: index)
    }

    /// Answers the request at `index` the way a server that accepted the command would.
    @discardableResult
    func acknowledge(at index: Int = 0) async throws -> HAMockConnection.PendingRequest {
        let pending = try await request(at: index)
        pending.completion(.success(.dictionary([:])))
        return pending
    }

    /// Names the REST path or the WebSocket command behind a request. HAKit exposes `command`
    /// only for the latter, and the `todo` services go out over REST.
    func route(of pending: HAMockConnection.PendingRequest) -> String {
        String(describing: pending.request.type)
    }

    /// The `todo.get_items` response shape, around the items a list holds.
    func todoItemsResponse(listId: String, items: [[String: Any]]) -> HAData {
        .dictionary([
            "changed_states": [],
            "service_response": [listId: ["items": items]],
        ])
    }

    private struct RequestNeverSent: Error {
        let index: Int
    }
}
