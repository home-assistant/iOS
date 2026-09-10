import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers what a vacuum command does when the drive takes the connection away: the request is
/// dispatched, and every outcome — reply, rejection, or no connection at all — settles and tells
/// the driver.
final class CarPlayVacuumControlViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    /// Held strongly: the view model's `templateProvider` is weak.
    private var template: CarPlayVacuumControlTemplate!
    private var sut: CarPlayVacuumControlViewModel!

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
        connection = nil
        server = nil
        super.tearDown()
    }

    /// Wires a mock connection in as the server's API, so requests are recorded rather than sent.
    private func connectAPI() {
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    /// A server the app cannot reach: `Current.api(for:)` yields nil for it, which is what a dead
    /// zone looks like from the CarPlay code's point of view. `Server.fake()` carries an external
    /// URL, so it is emphatically *not* offline.
    private func offlineServer() -> Server {
        Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
    }

    private func makeSut(offline: Bool = false) throws {
        if offline {
            server = offlineServer()
        }
        let entity = try HAEntity(
            entityId: "vacuum.living_room",
            state: "docked",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        sut = CarPlayVacuumControlViewModel(server: server, entity: entity)
        template = CarPlayVacuumControlTemplate(viewModel: sut)
    }

    // MARK: - Commands

    /// Without a connection the command never reaches the server, so it has to say so rather than
    /// look like it worked.
    func testACommandWithoutAConnectionReportsItRatherThanSendingAnything() throws {
        try makeSut(offline: true)

        sut.start()

        XCTAssertNil(Current.api(for: server))
    }

    func testACommandDispatchesARequest() throws {
        connectAPI()
        try makeSut()

        sut.start()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testACommandThatSucceedsSettles() throws {
        connectAPI()
        try makeSut()
        sut.start()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testACommandThatTheServerRejectsSettles() throws {
        connectAPI()
        try makeSut()
        sut.start()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    // MARK: - Clean areas

    /// The picker sits on "Loading…" until this answers, so a missing connection has to end the
    /// load rather than leave it spinning for the rest of the drive.
    func testLoadingAreasWithoutAConnectionFinishesImmediately() throws {
        try makeSut(offline: true)
        let finished = expectation(description: "load finished")

        sut.loadCleanableAreas { finished.fulfill() }

        wait(for: [finished], timeout: 1)
        XCTAssertFalse(sut.isLoadingAreas)
    }

    func testLoadingAreasMarksItselfInFlightUntilTheMappingArrives() throws {
        connectAPI()
        try makeSut()

        sut.loadCleanableAreas {}

        XCTAssertTrue(sut.isLoadingAreas)
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testLoadingAreasFinishesWhenTheMappingArrives() throws {
        connectAPI()
        try makeSut()
        let finished = expectation(description: "load finished")
        sut.loadCleanableAreas { finished.fulfill() }

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.dictionary(["area_ids": []])))

        wait(for: [finished], timeout: 10.0)
        XCTAssertFalse(sut.isLoadingAreas)
    }

    func testLoadingAreasFinishesWhenTheMappingRequestFails() throws {
        connectAPI()
        try makeSut()
        let finished = expectation(description: "load finished")
        sut.loadCleanableAreas { finished.fulfill() }

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        wait(for: [finished], timeout: 10.0)
        XCTAssertFalse(sut.isLoadingAreas)
    }
}
