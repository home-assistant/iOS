import PromiseKit
@testable import Shared
import XCTest

final class HAAPIPersistentEventTests: XCTestCase {
    private var previousWebhookManager: WebhookManager!
    private var webhookManager: FakeWebhookManager!

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        webhookManager = nil
        previousWebhookManager = nil
        super.tearDown()
    }

    func testImmediatePersistentEventStartsBackgroundTaskDirectly() {
        webhookManager.sendRequestHandler = { _, _, _, seal in seal.fulfill(()) }
        let api = HomeAssistantAPI(server: .fake())

        let result = api.startPersistentEvent(
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"]
        )

        guard case let .success(promise) = result else {
            return XCTFail("Expected the persisted upload task to start")
        }
        XCTAssertNoThrow(try hang(promise))
        XCTAssertEqual(webhookManager.startPersistedBackgroundCount, 1)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }
}
