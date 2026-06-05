@testable import HomeAssistant
@testable import Shared
import XCTest

final class LocalPushRetryDiagnosticsTests: XCTestCase {
    private var servers: FakeServerManager!

    override func setUp() {
        super.setUp()
        servers = FakeServerManager(initial: 0)
        Current.servers = servers
    }

    func testRetryEligibleWhenLocalPushEnabledAndCurrentSSIDMatches() {
        let server = makeServer(localPushEnabled: true, internalSSIDs: ["Home"])

        XCTAssertTrue(LocalPushRetryDiagnostics.canRetry(server: server, currentSSID: "Home"))
    }

    func testRetryIneligibleWhenLocalPushDisabled() {
        let server = makeServer(localPushEnabled: false, internalSSIDs: ["Home"])

        XCTAssertFalse(LocalPushRetryDiagnostics.canRetry(server: server, currentSSID: "Home"))
    }

    func testRetryIneligibleWhenCurrentSSIDIsNil() {
        let server = makeServer(localPushEnabled: true, internalSSIDs: ["Home"])

        XCTAssertFalse(LocalPushRetryDiagnostics.canRetry(server: server, currentSSID: nil))
    }

    func testRetryIneligibleWhenCurrentSSIDDoesNotMatch() {
        let server = makeServer(localPushEnabled: true, internalSSIDs: ["Home"])

        XCTAssertFalse(LocalPushRetryDiagnostics.canRetry(server: server, currentSSID: "Coffee Shop"))
    }

    func testRetryIneligibleWhenInternalURLIsMissing() {
        let server = makeServer(localPushEnabled: true, internalSSIDs: ["Home"], hasInternalURL: false)

        XCTAssertFalse(LocalPushRetryDiagnostics.canRetry(server: server, currentSSID: "Home"))
        XCTAssertTrue(LocalPushRetryDiagnostics.matchesExpectedNetworkConditions(server: server, currentSSID: "Home"))
    }

    func testPayloadContainsRetryContext() {
        let server = makeServer(localPushEnabled: true, internalSSIDs: ["Home"])

        let payload = LocalPushRetryDiagnostics.payload(
            server: server,
            reason: .appOpenDelayed(seconds: 30),
            currentSSID: "Home",
            managerCount: 1,
            activeManagerCount: 0,
            error: TestError.example
        )

        XCTAssertEqual(payload["server_id"] as? String, server.identifier.rawValue)
        XCTAssertEqual(payload["server_name"] as? String, server.info.name)
        XCTAssertEqual(payload["reason"] as? String, "app_open_30s")
        XCTAssertEqual(payload["current_ssid"] as? String, "Home")
        XCTAssertEqual(payload["configured_ssids"] as? [String], ["Home"])
        XCTAssertEqual(payload["local_push_enabled"] as? Bool, true)
        XCTAssertEqual(payload["has_internal_url"] as? Bool, true)
        XCTAssertEqual(payload["manager_count"] as? Int, 1)
        XCTAssertEqual(payload["active_manager_count"] as? Int, 0)
        XCTAssertEqual(payload["error"] as? String, String(describing: TestError.example))
    }

    private func makeServer(
        localPushEnabled: Bool,
        internalSSIDs: [String],
        hasInternalURL: Bool = true
    ) -> Server {
        let server = servers.addFake()
        server.update { info in
            info.connection.isLocalPushEnabled = localPushEnabled
            info.connection.internalSSIDs = internalSSIDs
            if hasInternalURL {
                info.connection.set(address: URL(string: "http://homeassistant.local:8123"), for: .internal)
            }
        }
        return server
    }

    private enum TestError: Error {
        case example
    }
}
