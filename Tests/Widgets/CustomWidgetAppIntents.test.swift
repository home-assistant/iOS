import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import UserNotifications
import XCTest

/// The intents a custom widget's tiles run: toggle, activate and perform action against a mock
/// connection, and the confirmation states they leave behind in an in-memory widget table.
@available(iOS 17, *)
final class CustomWidgetAppIntentsTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousDispatcher: LocalNotificationDispatcherProtocol!
    private var database: DatabaseQueue!
    private var dispatcher: RecordingNotificationDispatcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis
        previousDispatcher = Current.notificationDispatcher

        let database = try DatabaseQueue(path: ":memory:")
        try CustomWidgetTable().createIfNeeded(database: database)
        Current.database = { database }
        self.database = database

        Current.servers = FakeServerManager()
        dispatcher = RecordingNotificationDispatcher()
        Current.notificationDispatcher = dispatcher
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.cachedApis = previousCachedApis
        Current.notificationDispatcher = previousDispatcher
        database = nil
        dispatcher = nil
        super.tearDown()
    }

    // MARK: - Confirmation states

    func testResetClearsEveryWidgetsPendingStates() async throws {
        try insert(CustomWidget(id: "one", name: "One", items: [Self.item], itemsStates: [
            Self.item.serverUniqueId: .pendingConfirmation,
        ]))
        try insert(CustomWidget(id: "two", name: "Two", items: [], itemsStates: ["x": .pendingTapConfirmation]))

        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        let widgets = try XCTUnwrap(CustomWidget.widgets())
        XCTAssertEqual(widgets.count, 2)
        XCTAssertTrue(widgets.allSatisfy(\.itemsStates.isEmpty))
    }

    func testResetWithoutWidgetsDoesNothing() async throws {
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        XCTAssertEqual(try CustomWidget.widgets()?.count, 0)
    }

    func testUpdateConfirmationMarksTheTappedItem() async throws {
        try insert(CustomWidget(id: "widget", name: "Widget", items: [Self.item]))
        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = "widget"
        intent.serverUniqueId = Self.item.serverUniqueId

        _ = try await intent.perform()

        let widget = try XCTUnwrap(CustomWidget.widgets()?.first)
        XCTAssertEqual(widget.itemsStates, [Self.item.serverUniqueId: .pendingConfirmation])
    }

    func testUpdateConfirmationForTheRestOfASplitTile() async throws {
        try insert(CustomWidget(id: "widget", name: "Widget", items: [Self.item]))
        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = "widget"
        intent.serverUniqueId = Self.item.serverUniqueId
        intent.confirmsTapAction = true

        _ = try await intent.perform()

        let widget = try XCTUnwrap(CustomWidget.widgets()?.first)
        XCTAssertEqual(widget.itemsStates, [Self.item.serverUniqueId: .pendingTapConfirmation])
    }

    func testUpdateConfirmationForAnUnknownItemChangesNothing() async throws {
        try insert(CustomWidget(id: "widget", name: "Widget", items: [Self.item]))
        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = "widget"
        intent.serverUniqueId = "unknown"

        _ = try await intent.perform()

        XCTAssertEqual(try CustomWidget.widgets()?.first?.itemsStates, [:])
    }

    func testUpdateConfirmationWithMissingParametersChangesNothing() async throws {
        try insert(CustomWidget(id: "widget", name: "Widget", items: [Self.item], itemsStates: [
            Self.item.serverUniqueId: .pendingConfirmation,
        ]))
        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = "widget"

        _ = try await intent.perform()

        XCTAssertEqual(
            try CustomWidget.widgets()?.first?.itemsStates,
            [Self.item.serverUniqueId: .pendingConfirmation]
        )
    }

    // MARK: - Toggle

    func testToggleWithMissingParametersSendsNothing() async throws {
        let connection = connectServer()
        let intent = CustomWidgetToggleAppIntent()
        intent.serverId = Self.serverId
        intent.domain = "light"

        _ = try await intent.perform()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertNil(dispatcher.sent.first)
    }

    func testToggleWithUnknownDomainOrServerSendsNothing() async throws {
        let connection = connectServer()

        let unknownDomain = Self.toggleIntent(serverId: Self.serverId, domain: "not_a_domain", entityId: "x.y")
        _ = try await unknownDomain.perform()

        let unknownServer = Self.toggleIntent(serverId: "gone", domain: "light", entityId: "light.kitchen")
        _ = try await unknownServer.perform()

        let notToggleable = Self.toggleIntent(serverId: Self.serverId, domain: "sensor", entityId: "sensor.power")
        _ = try await notToggleable.perform()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(dispatcher.sent.isEmpty)
    }

    func testToggleCallsTheDomainServiceAndClearsConfirmations() async throws {
        let connection = connectServer()
        try insert(CustomWidget(id: "widget", name: "Widget", items: [Self.item], itemsStates: [
            Self.item.serverUniqueId: .pendingConfirmation,
        ]))
        let intent = Self.toggleIntent(serverId: Self.serverId, domain: "scene", entityId: "scene.movie")

        let task = Task { try await intent.perform() }
        let request = try await request(at: 0, on: connection)
        XCTAssertEqual(request.request.data["domain"] as? String, "scene")
        XCTAssertEqual(request.request.data["service"] as? String, "turn_on")
        request.completion(.success(.init(value: [String: Any]())))
        _ = try await task.value

        XCTAssertTrue(dispatcher.sent.isEmpty)
        XCTAssertEqual(try CustomWidget.widgets()?.first?.itemsStates, [:])
    }

    func testFailedToggleNotifies() async throws {
        let connection = connectServer()
        let intent = Self.toggleIntent(serverId: Self.serverId, domain: "scene", entityId: "scene.movie")

        let task = Task { try await intent.perform() }
        let request = try await request(at: 0, on: connection)
        request.completion(.failure(.internal(debugDescription: "offline")))
        _ = try await task.value

        XCTAssertEqual(dispatcher.sent.map(\.id), [.intentToggleFailed])
    }

    // MARK: - Activate

    func testActivateWithMissingOrUnusableParametersSendsNothing() async throws {
        let connection = connectServer()

        let missing = CustomWidgetActivateAppIntent()
        missing.serverId = Self.serverId
        _ = try await missing.perform()

        _ = try await Self.activateIntent(serverId: Self.serverId, domain: "nope", entityId: "nope.x").perform()
        _ = try await Self.activateIntent(serverId: "gone", domain: "scene", entityId: "scene.movie").perform()
        // A sensor has no main action to run.
        _ = try await Self.activateIntent(serverId: Self.serverId, domain: "sensor", entityId: "sensor.x").perform()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(dispatcher.sent.isEmpty)
    }

    func testActivateRunsTheMainAction() async throws {
        let connection = connectServer()
        let intent = Self.activateIntent(serverId: Self.serverId, domain: "scene", entityId: "scene.movie")

        let task = Task { try await intent.perform() }
        let request = try await request(at: 0, on: connection)
        XCTAssertEqual(request.request.data["domain"] as? String, "scene")
        request.completion(.success(.init(value: [String: Any]())))
        _ = try await task.value

        XCTAssertTrue(dispatcher.sent.isEmpty)
    }

    func testFailedActivateNotifies() async throws {
        let connection = connectServer()
        let intent = Self.activateIntent(serverId: Self.serverId, domain: "scene", entityId: "scene.movie")

        let task = Task { try await intent.perform() }
        let request = try await request(at: 0, on: connection)
        request.completion(.failure(.internal(debugDescription: "offline")))
        _ = try await task.value

        XCTAssertEqual(dispatcher.sent.map(\.id), [.intentActivateFailed])
    }

    // MARK: - Perform action

    func testPerformActionWithMissingOrUnusableParametersDoesNothing() async throws {
        let missing = CustomWidgetPerformActionAppIntent()
        missing.serverId = Self.serverId
        _ = try await missing.perform()

        let unusable = CustomWidgetPerformActionAppIntent()
        unusable.serverId = Self.serverId
        unusable.actionId = "light::turn_on"
        _ = try await unusable.perform()

        XCTAssertTrue(dispatcher.sent.isEmpty)
    }

    /// An action for a server the app no longer knows fails, and the tile says so.
    func testPerformActionOnAnUnknownServerNotifies() async throws {
        let intent = CustomWidgetPerformActionAppIntent()
        intent.serverId = "gone"
        intent.actionId = "light.turn_on"
        intent.payload = "{}"

        _ = try await intent.perform()

        XCTAssertEqual(dispatcher.sent.map(\.id), [.intentPerformActionFailed])
    }

    // MARK: - Entity query

    func testCustomWidgetQueryFindsWidgetsByIdAndName() async throws {
        try insert(CustomWidget(id: "a", name: "Living Room", items: []))
        try insert(CustomWidget(id: "b", name: "Garage", items: []))
        let query = CustomWidgetAppEntityQuery()

        let byId = try await query.entities(for: ["b", "missing"])
        XCTAssertEqual(byId.map(\.id), ["b"])
        XCTAssertEqual(byId.first?.name, "Garage")

        _ = try await query.entities(matching: "living")
        _ = try await query.suggestedEntities()

        let entity = CustomWidgetEntity(id: "a", name: "Living Room")
        XCTAssertEqual(entity.name, "Living Room")
        _ = entity.displayRepresentation
    }

    func testCustomWidgetQueryWithoutATableIsEmpty() async throws {
        let empty = try DatabaseQueue(path: ":memory:")
        Current.database = { empty }

        let entities = try await CustomWidgetAppEntityQuery().entities(for: ["a"])

        XCTAssertTrue(entities.isEmpty)
    }

    func testCustomAppIntentDefaults() async throws {
        let intent = WidgetCustomAppIntent()
        XCTAssertFalse(intent.showLastUpdateTime)
        XCTAssertTrue(intent.showStates)
        XCTAssertNil(intent.widget)
        _ = try await intent.perform()
        XCTAssertFalse(String(describing: WidgetCustomAppIntent.parameterSummary).isEmpty)
        XCTAssertEqual(WidgetCustomConstants.expiration.converted(to: .seconds).value, 15 * 60)
    }

    // MARK: - Helpers

    private static let serverId = "custom-widget-server"
    private static let item = MagicItem(id: "light.kitchen", serverId: serverId, type: .entity)

    private static func toggleIntent(serverId: String, domain: String, entityId: String) -> CustomWidgetToggleAppIntent {
        let intent = CustomWidgetToggleAppIntent()
        intent.serverId = serverId
        intent.domain = domain
        intent.entityId = entityId
        intent.widgetShowingStates = false
        return intent
    }

    private static func activateIntent(
        serverId: String,
        domain: String,
        entityId: String
    ) -> CustomWidgetActivateAppIntent {
        let intent = CustomWidgetActivateAppIntent()
        intent.serverId = serverId
        intent.domain = domain
        intent.entityId = entityId
        return intent
    }

    private func connectServer() -> HAMockConnection {
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return connection
    }

    private func insert(_ widget: CustomWidget) throws {
        try database.write { db in
            try widget.insert(db)
        }
    }

    /// The intents send from their own task, so wait for the request to reach the mock connection.
    private func request(
        at index: Int,
        on connection: HAMockConnection
    ) async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 300 {
            if connection.pendingRequests.count > index {
                return connection.pendingRequests[index]
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent()
    }

    private struct RequestNeverSent: Error {}

    private final class RecordingNotificationDispatcher: LocalNotificationDispatcherProtocol {
        private(set) var sent: [LocalNotificationDispatcher.Notification] = []

        func send(_ notification: LocalNotificationDispatcher.Notification) {
            sent.append(notification)
        }

        func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {}
    }
}
