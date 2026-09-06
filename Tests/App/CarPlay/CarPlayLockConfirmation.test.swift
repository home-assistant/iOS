import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// A lock action reports what happened rather than only logging it, so the row can settle and the
/// driver can be told when it didn't go through.
final class CarPlayLockConfirmationTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    func testASuccessfulLockActionReportsNoError() throws {
        var reported: Error?
        var didReport = false

        CarPlayLockConfirmation.execute(entityId: "lock.front_door", currentState: "locked", api: api) { error in
            reported = error
            didReport = true
        }

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))

        let settled = expectation(description: "settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertTrue(didReport)
        XCTAssertNil(reported)
    }

    func testALockActionTheServerRejectsReportsTheError() throws {
        let reported = expectation(description: "error reported")
        var error: Error?

        CarPlayLockConfirmation.execute(entityId: "lock.front_door", currentState: "locked", api: api) {
            error = $0
            reported.fulfill()
        }

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))

        wait(for: [reported], timeout: 2)
        XCTAssertNotNil(error)
    }

    /// An entity id the row can't build an entity from never reaches the server, and has to say so.
    func testALockActionWithAnUnusableEntityIdReportsAnError() {
        let reported = expectation(description: "error reported")
        var error: Error?

        CarPlayLockConfirmation.execute(entityId: "", currentState: "locked", api: api) {
            error = $0
            reported.fulfill()
        }

        wait(for: [reported], timeout: 2)
        XCTAssertNotNil(error)
    }
}
