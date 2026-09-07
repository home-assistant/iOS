import CarPlay
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers what tapping a Quick Access row does once a request is in flight: the action is
/// dispatched, a repeat tap is ignored while it is outstanding, and every outcome settles the row.
final class CarPlayQuickAccessTemplateTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var sut: CarPlayQuickAccessTemplate!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        sut = CarPlayQuickAccessTemplate(viewModel: CarPlayQuickAccessViewModel())
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        sut = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    private func connectAPI() {
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    /// `CarPlayPaginatedListTemplate` applies its rows asynchronously, so the sections are only
    /// readable once the main queue has turned over.
    private func drainMainQueue(cycles: Int = 3) {
        let drained = expectation(description: "main queue drained")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    drained.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [drained], timeout: 5)
    }

    private func item(id: String, type: MagicItem.ItemType) -> MagicItem {
        MagicItem(id: id, serverId: server.identifier.rawValue, type: type)
    }

    /// Renders the given items as a list (rather than the iOS 26 grid) and returns the rows, whose
    /// handlers are what a tap in the car runs.
    private func rows(for items: [MagicItem]) -> [CPListItem] {
        sut.updateList(for: items, layout: .list, showAddEditButtons: false)
        drainMainQueue()
        return sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListItem }
    }

    private func tap(_ row: CPListItem) {
        row.handler?(row, {})
    }

    /// Gives the template a live state for an entity. Locks need one: an unrecognised state sends
    /// nothing, and an unseeded row resolves to a placeholder whose state is empty.
    private func seedState(entityId: String, state: String) throws {
        let entity = try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: [entityId: entity])
        )
    }

    func testTappingAnEntityRowDispatchesItsAction() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// The row sits on "Executing…" while the call is outstanding, and on a slow connection that is
    /// long enough to invite a second tap — which must not run the action twice.
    func testASecondTapWhileTheFirstIsInFlightIsIgnored() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        let row = try XCTUnwrap(rendered.first)

        tap(row)
        drainMainQueue()
        tap(row)
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testATapThatSucceedsSettlesTheRow() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testATapTheServerRejectsSettlesTheRow() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testTappingAScriptRowDispatchesItsAction() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "script.good_morning", type: .script)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertFalse(rendered.isEmpty)
    }

    /// A Quick Access item can outlive the server it points at; tapping it must fail visibly rather
    /// than silently do nothing.
    func testTappingAnItemWhoseServerIsGoneDoesNotDispatchAnything() throws {
        connectAPI()
        let orphan = MagicItem(id: "light.kitchen", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Locks always confirm first: the action must not reach the server until the driver taps
    /// through the confirmation.
    func testALockRowRunsItsActionOnlyOnceConfirmed() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        try seedState(entityId: "lock.front_door", state: "locked")
        let rendered = rows(for: [item(id: "lock.front_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        drainMainQueue()
    }

    /// A lock whose server is gone can't run, and the driver has to be told rather than left with a
    /// row that quietly did nothing.
    func testALockRowWhoseServerIsGoneRunsNothing() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let orphan = MagicItem(id: "lock.front_door", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// A lock on a server the app can't reach: same, but the reason is the connection.
    func testALockRowWithoutAReachableServerRunsNothing() throws {
        connectAPI()
        let unreachable = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let servers = try XCTUnwrap(Current.servers as? FakeServerManager)
        servers.add(identifier: unreachable.identifier, serverInfo: unreachable.info)
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let item = MagicItem(
            id: "lock.front_door",
            serverId: unreachable.identifier.rawValue,
            type: .entity
        )
        let rendered = rows(for: [item])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testCancellingALockConfirmationRunsNothing() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let rendered = rows(for: [item(id: "lock.front_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let cancel = try XCTUnwrap(alert.actions.first)
        cancel.handler(cancel)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Climate rows open a control screen instead of executing, and a missing server leaves nothing
    /// to open.
    func testTappingAClimateRowWhoseServerIsGoneOpensNothing() throws {
        connectAPI()
        let orphan = MagicItem(id: "climate.hall", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
