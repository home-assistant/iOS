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

    private func makeSut(
        entityId: String = "light.kitchen",
        domain: String = "light",
        state: String = "on"
    ) throws {
        entity = try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        let states = HACachedStates(entitiesDictionary: [entityId: entity])
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
        try makeSut()
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 2)
    }

    func testATapReleasesTheRowHandlerWithoutWaitingForTheServer() throws {
        connectAPI()
        try makeSut()
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 2)
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testATapMarksTheRowExecutingUntilTheServerAnswers() throws {
        connectAPI()
        try makeSut()
        var finished = false

        sut.handleEntityTap(
            entity: entity,
            executionFinished: { finished = true },
            completion: {}
        )

        XCTAssertFalse(finished)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))

        let settled = expectation(description: "execution settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)
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

        wait(for: [settled], timeout: 2)
    }

    /// Climate rows open a control screen rather than executing anything.
    func testTappingAControlScreenEntityDispatchesNothing() throws {
        connectAPI()
        try makeSut(entityId: "climate.hall", domain: "climate", state: "heat")
        let released = expectation(description: "row handler released")

        sut.handleEntityTap(entity: entity) { released.fulfill() }

        wait(for: [released], timeout: 2)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
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
}
