import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPIGetConfigTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        ServerFixture.reset()
        super.tearDown()
    }

    func testStoresWhatTheServerReportsAboutItself() throws {
        let server = ServerFixture.standard
        let api = HomeAssistantAPI(server: server)
        webhookManager.sendEphemeralHandler = { _, _ in
            [
                "version": "2026.9.3",
                "location_name": "Casa",
                "hass_device_id": "device-1",
                "instance_id": "instance-1",
            ]
        }

        try hang(api.getConfig())

        XCTAssertEqual(server.info.instanceID, "instance-1")
        XCTAssertEqual(server.info.hassDeviceId, "device-1")
        XCTAssertEqual(server.info.remoteName, "Casa")
        XCTAssertEqual(server.info.version, Version(major: 2026, minor: 9, patch: 3))
    }

    func testKeepsTheStoredInstanceIDWhenTheServerDoesNotReportOne() throws {
        let server = ServerFixture.standard
        server.update { $0.instanceID = "instance-1" }
        let api = HomeAssistantAPI(server: server)
        webhookManager.sendEphemeralHandler = { _, _ in
            [
                "version": "2026.9.3",
                "location_name": "Casa",
            ]
        }

        try hang(api.getConfig())

        XCTAssertEqual(server.info.instanceID, "instance-1")
    }
}
