import CarPlay
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers what tapping an entity row does when the drive takes the connection away: CarPlay's row
/// handler is always released, the action is dispatched when there is a connection, and every
/// outcome settles the row.
final class CarPlayEntitiesListViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    /// Held strongly: the view model's `templateProvider` is weak.
    private var template: CarPlayEntitiesListTemplate!
    private var sut: CarPlayEntitiesListViewModel!
    private var entity: HAEntity!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        template = nil
        sut = nil
        entity = nil
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

    /// A server the app cannot reach — `Server.fake()` carries an external URL, so it is not one.
    private func offlineServer() -> Server {
        Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
    }

    private func makeSut(
        entityId: String = "light.kitchen",
        domain: String = "light",
        state: String = "on",
        offline: Bool = false,
        entities: [HAEntity]? = nil
    ) throws {
        if offline {
            server = offlineServer()
        }
        let entities = try entities ?? [makeEntity(entityId: entityId, state: state)]
        entity = entities.first
        let states = cachedStates(entities)
        sut = CarPlayEntitiesListViewModel(
            filterType: .domain(domain),
            server: server,
            entitiesCachedStates: states
        )
        template = CarPlayEntitiesListTemplate(viewModel: sut, title: "Lights")
        sut.update()
    }

    /// CarPlay keeps the row busy until its handler's completion runs, so an offline tap has to
    /// release it rather than leave the row spinning.
    func testATapWithoutAConnectionStillReleasesTheRowHandler() throws {
        try makeSut(offline: true)
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 30)
    }

    func testATapReleasesTheRowHandlerWithoutWaitingForTheServer() throws {
        connectAPI()
        try makeSut()
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 30)
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testTappingAnOpenCoverClosesIt() throws {
        connectAPI()
        try makeSut(entityId: "cover.garage_door", domain: "cover", state: "open")
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 30)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(request.request.data["service"] as? String, "close_cover")
    }

    func testATapMarksTheRowExecutingUntilTheServerAnswers() throws {
        connectAPI()
        try makeSut()
        // Waiting on the callback itself rather than a main-queue hop: the reply travels through
        // PromiseKit before the deadline reports, so a fixed number of hops races it.
        let settled = expectation(description: "execution settled")
        var finished = false

        sut.handleEntityTap(
            entity: entity,
            executionFinished: {
                finished = true
                settled.fulfill()
            },
            completion: {}
        )

        XCTAssertFalse(finished)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))

        wait(for: [settled], timeout: 30)
        XCTAssertTrue(finished)
    }

    func testATapTheServerRejectsStillSettlesTheRow() throws {
        connectAPI()
        try makeSut()
        let settled = expectation(description: "execution settled")

        sut.handleEntityTap(
            entity: entity,
            executionFinished: { settled.fulfill() },
            completion: {}
        )

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        wait(for: [settled], timeout: 30)
    }

    /// Climate rows open a control screen rather than executing anything.
    func testTappingAControlScreenEntityDispatchesNothing() throws {
        connectAPI()
        try makeSut(entityId: "climate.hall", domain: "climate", state: "heat")
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 30)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Locks always confirm first: nothing reaches the server until the driver taps through.
    func testALockEntityRunsItsActionOnlyOnceConfirmed() throws {
        connectAPI()
        try makeSut(entityId: "lock.front_door", domain: "lock", state: "locked")
        let presenter = FakeCarPlayAlertPresenter()
        template.alertPresenterOverride = presenter

        let settled = expectation(description: "execution settled")
        sut.handleEntityTap(entity: entity, executionFinished: { settled.fulfill() }, completion: {})
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)

        XCTAssertEqual(connection.pendingRequests.count, 1)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        wait(for: [settled], timeout: 30)
    }

    /// The rendered rows carry the same repeat-tap guard the view model does.
    @available(iOS 26.0, *)
    func testACondensedRowRefusesARepeatTapWhileItsCallIsInFlight() throws {
        connectAPI()
        try makeSut()
        drainMainQueue()
        let items = template.template.sections.flatMap(\.items)
        let row = try XCTUnwrap(items.compactMap { $0 as? CPListImageRowItem }.first)

        row.listImageRowHandler?(row, 0, {})
        drainMainQueue()
        row.listImageRowHandler?(row, 0, {})
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// `CarPlayPaginatedListTemplate` applies its rows asynchronously.
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
        wait(for: [drained], timeout: 30.0)
    }

    /// The row refuses a repeat tap while its call is outstanding, which is what stops a slow
    /// connection from running the action twice.
    func testARowReportsItselfInFlightWhileItsCallIsOutstanding() throws {
        connectAPI()
        try makeSut()
        let provider = CarPlayEntityListItem(serverId: server.identifier.rawValue, entity: entity)

        XCTAssertFalse(provider.isOperationInFlight)
        provider.setExecutingState(true)
        XCTAssertTrue(provider.isOperationInFlight)
        provider.setExecutingState(false)
        XCTAssertFalse(provider.isOperationInFlight)
    }

    @available(iOS 26.0, *)
    func testStateUpdatesPreserveProviderOrderWhenNamesChange() throws {
        let hall = try makeEntity(entityId: "light.hall", name: "Hall")
        let kitchen = try makeEntity(entityId: "light.kitchen", name: "Kitchen")
        try makeSut(entities: [hall, kitchen])
        drainMainQueue()
        XCTAssertEqual(try displayedEntityNames(), ["Hall", "Kitchen"])

        let updatedHall = try makeEntity(entityId: "light.hall", name: "Zulu")
        let updatedKitchen = try makeEntity(entityId: "light.kitchen", name: "Alpha")
        sut.updateStates(entities: cachedStates([updatedHall, updatedKitchen]))
        drainMainQueue()

        XCTAssertEqual(try displayedEntityNames(), ["Zulu", "Alpha"])
    }

    @available(iOS 26.0, *)
    func testStateUpdatesDoNotInsertNewEntities() throws {
        let hall = try makeEntity(entityId: "light.hall", name: "Hall")
        let kitchen = try makeEntity(entityId: "light.kitchen", name: "Kitchen")
        try makeSut(entities: [hall, kitchen])
        drainMainQueue()

        let updatedKitchen = try makeEntity(entityId: "light.kitchen", name: "Kitchen updated")
        let added = try makeEntity(entityId: "light.new", name: "New")
        let otherDomain = try makeEntity(entityId: "sensor.room", name: "Room")
        sut.updateStates(entities: cachedStates([hall, updatedKitchen, added, otherDomain]))
        drainMainQueue()

        XCTAssertEqual(try displayedEntityNames(), ["Hall", "Kitchen updated"])
    }

    @available(iOS 26.0, *)
    func testUnchangedStatesDoNotReplacePresentedRows() throws {
        let hall = try makeEntity(entityId: "light.hall", name: "Hall")
        try makeSut(entities: [hall])
        drainMainQueue()
        let originalRow = try XCTUnwrap(template.template.sections.flatMap(\.items).first as? CPListImageRowItem)

        sut.updateStates(entities: cachedStates([hall]))
        drainMainQueue()

        let currentRow = try XCTUnwrap(template.template.sections.flatMap(\.items).first as? CPListImageRowItem)
        XCTAssertTrue(currentRow === originalRow)
    }

    private func makeEntity(
        entityId: String,
        state: String = "on",
        name: String? = nil
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(timeIntervalSince1970: 0),
            lastUpdated: Date(timeIntervalSince1970: 0),
            attributes: name.map { ["friendly_name": $0] } ?? [:],
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func cachedStates(_ entities: [HAEntity]) -> HACachedStates {
        HACachedStates(entitiesDictionary: Dictionary(uniqueKeysWithValues: entities.map { ($0.entityId, $0) }))
    }

    @available(iOS 26.0, *)
    private func displayedEntityNames() throws -> [String] {
        let rows = template.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
        let elements = rows.flatMap(\.elements)
        return try elements.map { try XCTUnwrap($0 as? CPListImageRowItemCondensedElement).title }
    }
}
