import CarPlay
import GRDB
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
        // A request or subscription the test never answers holds the code under test, and through it
        // the API: XCTest keeps this test case alive for the whole run, and an API left alive stays
        // registered with the app's sensor container, which every later sensor signal fans out to.
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
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

    // MARK: - Filtering, sorting and the database

    /// Swaps in an in-memory database for the body, restoring the app's afterwards.
    private func withDatabase(_ database: DatabaseQueue, _ body: () throws -> Void) rethrows {
        let previous = Current.database
        Current.database = { database }
        defer { Current.database = previous }
        try body()
    }

    private func entity(_ entityId: String, state: String, attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(timeIntervalSince1970: 0),
            lastUpdated: Date(timeIntervalSince1970: 0),
            attributes: attributes,
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    @available(iOS 26.0, *)
    func testHiddenEntitiesAreLeftOutAndAreasNameTheRest() throws {
        let database = try CarPlayTestDatabase.make()
        try database.write { db in
            var hidden = try EntityRegistryListForDisplay.Entity(data: .dictionary(["ei": "light.hidden", "hb": true]))
            hidden.serverId = self.server.identifier.rawValue
            try hidden.insert(db)
            try AppArea(
                id: "kitchen", serverId: self.server.identifier.rawValue, areaId: "kitchen", name: "Kitchen",
                aliases: [], picture: nil, icon: nil, sortOrder: nil, entities: ["light.kitchen"]
            ).insert(db)
        }

        try withDatabase(database) {
            try makeSut(entities: [
                makeEntity(entityId: "light.kitchen", name: "Kitchen light"),
                makeEntity(entityId: "light.hidden", name: "Hidden light"),
            ])
            drainMainQueue()
        }

        XCTAssertEqual(try displayedEntityNames(), ["Kitchen light"])
        let element = template.template.sections.flatMap(\.items)
            .compactMap { $0 as? CPListImageRowItem }.first?.elements.first as? CPListImageRowItemCondensedElement
        XCTAssertEqual(element?.subtitle?.hasSuffix("Kitchen"), true)
    }

    @available(iOS 26.0, *)
    func testAnAreaListOnlyShowsItsSupportedEntities() throws {
        let states = try cachedStates([
            makeEntity(entityId: "light.kitchen", name: "Kitchen light"),
            makeEntity(entityId: "sensor.temperature", name: "Temperature"),
            makeEntity(entityId: "mystery.thing", name: "Mystery"),
            makeEntity(entityId: "light.elsewhere", name: "Elsewhere"),
        ])
        sut = CarPlayEntitiesListViewModel(
            filterType: .areaId(entityIds: ["light.kitchen", "sensor.temperature", "mystery.thing"]),
            server: server,
            entitiesCachedStates: states
        )
        template = CarPlayEntitiesListTemplate(viewModel: sut, title: "Kitchen")
        sut.update()
        drainMainQueue()

        XCTAssertEqual(try displayedEntityNames(), ["Kitchen light"])
    }

    /// Garage doors and gates come first, unavailable or unknown entities last.
    @available(iOS 26.0, *)
    func testGaragesSortFirstAndUnavailableEntitiesLast() throws {
        try makeSut(domain: "cover", entities: [
            entity("cover.broken", state: "unavailable", attributes: ["friendly_name": "Broken"]),
            entity("cover.blind", state: "open", attributes: ["friendly_name": "Blind"]),
            entity("cover.lost", state: "unknown", attributes: ["friendly_name": "Lost"]),
            entity("cover.garage", state: "closed", attributes: ["friendly_name": "Garage", "device_class": "garage"]),
            entity("cover.gate", state: "closed", attributes: ["friendly_name": "Gate", "device_class": "gate"]),
        ])
        drainMainQueue()

        let names = try displayedEntityNames()
        XCTAssertEqual(Array(names.prefix(2)).sorted(), ["Garage", "Gate"])
        XCTAssertEqual(names[2], "Blind")
        XCTAssertEqual(Array(names.suffix(2)).sorted(), ["Broken", "Lost"])
    }

    func testAnUnreadableDatabaseStillListsTheEntities() throws {
        let broken = try CarPlayTestDatabase.broken()
        try withDatabase(broken) {
            try makeSut()
            drainMainQueue()
        }

        XCTAssertFalse(template.template.sections.flatMap(\.items).isEmpty)
    }

    func testALockTheServerRejectsStillSettles() throws {
        connectAPI()
        try makeSut(entityId: "lock.front_door", domain: "lock", state: "locked")
        let presenter = FakeCarPlayAlertPresenter()
        template.alertPresenterOverride = presenter

        let settled = expectation(description: "execution settled")
        sut.handleEntityTap(entity: entity, executionFinished: { settled.fulfill() }, completion: {})
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        wait(for: [settled], timeout: 30)
    }

    /// The executing subtitle outlives a fast answer; when it finally clears, the list redraws.
    @available(iOS 26.0, *)
    func testTheListRedrawsWhenTheExecutingSubtitleClears() throws {
        connectAPI()
        try makeSut()
        drainMainQueue()
        let row = try XCTUnwrap(
            template.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }.first
        )
        row.listImageRowHandler?(row, 0, {})
        drainMainQueue()
        try XCTUnwrap(connection.pendingRequests.first).completion(.success(.empty))

        let deadline = Date().addingTimeInterval(10)
        func subtitle() -> String? {
            let current = template.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
            return (current.first?.elements.first as? CPListImageRowItemCondensedElement)?.subtitle
        }
        while subtitle() == CarPlayEntityListItem.executingSubtitle || subtitle() == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        // The redrawn row must still be there, showing its state rather than the executing text.
        let redrawn = try XCTUnwrap(subtitle(), "the redrawn row has no subtitle")
        XCTAssertNotEqual(redrawn, CarPlayEntityListItem.executingSubtitle)
    }
}
