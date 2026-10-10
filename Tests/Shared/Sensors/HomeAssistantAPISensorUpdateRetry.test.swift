import Foundation
import PromiseKit
@testable import Shared
import XCTest

/// The retry wired into the API: a failed `update_sensor_states` is sent again later, and a
/// successful one in between calls it off.
class HomeAssistantAPISensorUpdateRetryTests: XCTestCase {
    private enum TestError: Error {
        case unreachable
    }

    private var api: HomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var scheduled: [(delay: TimeInterval, block: () -> Void)] = []

    override func setUp() {
        super.setUp()
        Current.isAppExtension = false
        api = HomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        previousWebhookManager = Current.webhooks
        Current.webhooks = webhookManager
        scheduled = []
        api.sensorUpdateRetry.schedule = { [weak self] delay, block in
            self?.scheduled.append((delay, block))
        }
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        api = nil
        super.tearDown()
    }

    private func answerSensorUpdates(
        succeeding: Bool,
        onRequest: @escaping (WebhookRequest) -> Void = { _ in }
    ) {
        webhookManager.sendRequestHandler = { _, _, request, seal in
            onRequest(request)
            if succeeding {
                seal.fulfill(())
            } else {
                seal.reject(TestError.unreachable)
            }
        }
    }

    func testAFailedUpdateIsSentAgainWhenTheRetryFires() throws {
        var sent = 0
        answerSensorUpdates(succeeding: false) { request in
            if request.type == "update_sensor_states" { sent += 1 }
        }

        XCTAssertThrowsError(try hang(api.UpdateSensors(trigger: .Launch)))
        XCTAssertEqual(sent, 1)
        XCTAssertEqual(scheduled.count, 1)

        let retried = expectation(description: "retried")
        answerSensorUpdates(succeeding: true) { request in
            if request.type == "update_sensor_states" {
                sent += 1
                retried.fulfill()
            }
        }
        scheduled[0].block()
        wait(for: [retried], timeout: 10)
        XCTAssertEqual(sent, 2)
    }

    func testASuccessfulUpdateInBetweenCallsTheRetryOff() throws {
        answerSensorUpdates(succeeding: false)
        XCTAssertThrowsError(try hang(api.UpdateSensors(trigger: .Launch)))
        XCTAssertEqual(scheduled.count, 1)

        var sent = 0
        answerSensorUpdates(succeeding: true) { request in
            if request.type == "update_sensor_states" { sent += 1 }
        }
        try hang(api.UpdateSensors(trigger: .Periodic))
        XCTAssertEqual(sent, 1)

        scheduled[0].block()
        // Nothing fires asynchronously for a cancelled retry, so give any stray send a moment.
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 5)
        XCTAssertEqual(sent, 1)
    }
}
