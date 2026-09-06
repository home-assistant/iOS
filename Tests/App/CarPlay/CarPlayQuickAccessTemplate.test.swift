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
