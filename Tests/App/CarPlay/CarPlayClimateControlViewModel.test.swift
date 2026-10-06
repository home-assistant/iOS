import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers what a climate adjustment does when the drive takes the connection away. Adjustments are
/// debounced before they are sent, so each test waits for that window to close.
final class CarPlayClimateControlViewModelTests: XCTestCase {
    /// Comfortably longer than the view model's send debounce.
    private let debounceWindow: TimeInterval = 1.5

    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    /// Held strongly: the view model's `templateProvider` is weak.
    private var template: CarPlayClimateControlTemplate!
    private var sut: CarPlayClimateControlViewModel!

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

    private func makeSut(offline: Bool = false) throws {
        if offline {
            server = offlineServer()
        }
        let entity = try HAEntity(
            entityId: "climate.living_room",
            state: "heat",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "temperature": 20.0,
                "current_temperature": 19.0,
                "min_temp": 7.0,
                "max_temp": 35.0,
            ],
            context: .init(id: "", userId: "", parentId: "")
        )
        sut = CarPlayClimateControlViewModel(server: server, entity: entity)
        template = CarPlayClimateControlTemplate(viewModel: sut)
    }

    /// Lets the debounce window close so the queued adjustment is actually dispatched.
    private func waitForDebounce() {
        let settled = expectation(description: "debounce window closed")
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceWindow) { settled.fulfill() }
        wait(for: [settled], timeout: debounceWindow + 2)
    }

    func testAnAdjustmentWithoutAConnectionSendsNothing() throws {
        try makeSut(offline: true)

        sut.adjustTargetTemperature(by: 1)
        waitForDebounce()

        XCTAssertNil(Current.api(for: server))
    }

    func testAnAdjustmentDispatchesARequestOnceTheDebounceCloses() throws {
        connectAPI()
        try makeSut()

        sut.adjustTargetTemperature(by: 1)
        waitForDebounce()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testAnAdjustmentThatSucceedsSettles() throws {
        connectAPI()
        try makeSut()
        sut.adjustTargetTemperature(by: 1)
        waitForDebounce()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testAnAdjustmentTheServerRejectsSettles() throws {
        connectAPI()
        try makeSut()
        sut.adjustTargetTemperature(by: 1)
        waitForDebounce()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }
}
