import Foundation
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

    func testImmediatePersistentEventStartsBackgroundTaskDirectly() async {
        webhookManager.sendRequestHandler = { _, _, _, seal in seal.fulfill(()) }
        let api = HomeAssistantAPI(server: .fake())

        let eventIdentifier = UUID()
        let result = api.startPersistentEvent(
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            eventIdentifier: eventIdentifier
        )

        guard case let .success(delivery) = result else {
            return XCTFail("Expected the persisted upload task to start")
        }
        do {
            try await delivery.value
        } catch {
            XCTFail("Expected successful delivery, got \(error)")
        }
        XCTAssertEqual(webhookManager.startPersistedBackgroundCount, 1)
        XCTAssertEqual(webhookManager.persistedRequestIdentifiers, [eventIdentifier.uuidString])
        XCTAssertEqual(webhookManager.sendCount, 0)
    }
}
