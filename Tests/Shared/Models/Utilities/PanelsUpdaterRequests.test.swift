import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared
import XCTest

final class PanelsUpdaterRequestsTests: XCTestCase {
    private class StubAPI: HomeAssistantAPI {}

    private var previousServers: ServerManager!
    private var previousIsAppExtension: Bool!
    private var server: Server!
    private var connection: HAMockConnection!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousIsAppExtension = Current.isAppExtension
        Current.isAppExtension = false

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = StubAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api
    }

    override func tearDown() {
        Current.cachedApis[server.identifier] = nil
        Current.servers = previousServers
        Current.isAppExtension = previousIsAppExtension
        super.tearDown()
    }

    func testUpdateRequestsPanelsForEachServer() {
        let updater = PanelsUpdater()

        updater.update()

        XCTAssertEqual(connection.pendingRequests.count, 1)
        XCTAssertEqual(connection.pendingRequests.first?.request.type, .webSocket("get_panels"))
    }

    func testUpdateWithinFiveSecondsIsSkipped() {
        let updater = PanelsUpdater()

        updater.update()
        updater.update()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testUpdateIsSkippedInAppExtension() {
        Current.isAppExtension = true
        let updater = PanelsUpdater()

        updater.update()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
