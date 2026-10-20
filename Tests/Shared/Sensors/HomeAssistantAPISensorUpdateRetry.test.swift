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
    private var previousSensors: SensorContainer!
    private var scheduled: [(delay: TimeInterval, block: () -> Void)] = []

    override func setUp() {
        super.setUp()
        Current.isAppExtension = false
        api = HomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        previousWebhookManager = Current.webhooks
        Current.webhooks = webhookManager
        previousSensors = Current.sensors
        scheduled = []
        api.sensorUpdateRetry.schedule = { [weak self] delay, block in
            self?.scheduled.append((delay, block))
        }
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        Current.sensors = previousSensors
        GatedSensorProvider.pendingReads = []
        api = nil
        super.tearDown()
    }

    /// Starts an update and waits for its request to reach the webhook manager, handing back the
    /// resolver that answers it. Sensor collection is asynchronous, so two updates started back to
    /// back do not necessarily send in that order; waiting for each pins the order down.
    private func startUpdate(trigger: LocationUpdateTrigger) throws -> (update: Promise<Void>, answer: Resolver<Void>) {
        var answer: Resolver<Void>?
        let sent = expectation(description: "update for \(trigger) sent")
        webhookManager.sendRequestHandler = { _, _, _, seal in
            answer = seal
            sent.fulfill()
        }
        let update = api.UpdateSensors(trigger: trigger)
        wait(for: [sent], timeout: 10)
        return try (update, XCTUnwrap(answer))
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

    /// `WebhookManager` cancels an in-flight `update_sensor_states` when a newer one for the same
    /// server starts, rejecting it with `.replaced`. When the server answers the newer one first,
    /// the replaced one's failure arrives after the success that overtook it and owes no retry.
    func testAReplacedUpdateOvertakenByASuccessDoesNotScheduleARetry() throws {
        let older = try startUpdate(trigger: .Launch)
        let newer = try startUpdate(trigger: .Periodic)

        newer.answer.fulfill(())
        try hang(newer.update)
        older.answer.reject(WebhookError.replaced)
        XCTAssertThrowsError(try hang(older.update))

        XCTAssertTrue(scheduled.isEmpty)
    }

    /// Overlapping runs read their sensors in whatever order their providers resolve, so the run
    /// that started first can read, and send, last. Its request then carries the newest values and
    /// a failure to deliver them is owed a retry, however early it started.
    func testAnEarlierRunThatSendsLastIsStillRetried() throws {
        let sensors = SensorContainer()
        sensors.register(provider: GatedSensorProvider.self)
        Current.sensors = sensors

        var answers = [Resolver<Void>]()
        let sent = expectation(description: "both updates sent")
        sent.expectedFulfillmentCount = 2
        webhookManager.sendRequestHandler = { _, _, _, seal in
            answers.append(seal)
            sent.fulfill()
        }

        let earlier = api.UpdateSensors(trigger: .Launch)
        let later = api.UpdateSensors(trigger: .Periodic)
        XCTAssertEqual(GatedSensorProvider.pendingReads.count, 2)

        // The later run reads first, so it sends first; the earlier one reads a newer value after it.
        GatedSensorProvider.pendingReads[1].fulfill([.init(name: "test", uniqueID: "test", state: "old")])
        GatedSensorProvider.pendingReads[0].fulfill([.init(name: "test", uniqueID: "test", state: "new")])
        wait(for: [sent], timeout: 10)

        answers[0].fulfill(())
        try hang(later)
        answers[1].reject(TestError.unreachable)
        XCTAssertThrowsError(try hang(earlier))

        XCTAssertEqual(scheduled.count, 1)
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

/// Reads only when the test lets it, so one run can be held open while another overtakes it.
private class GatedSensorProvider: SensorProvider {
    /// One per run, in the order the runs started.
    static var pendingReads = [Resolver<[WebhookSensor]>]()

    required init(request: SensorProviderRequest) {}

    func sensors() -> Promise<[WebhookSensor]> {
        let (promise, seal) = Promise<[WebhookSensor]>.pending()
        Self.pendingReads.append(seal)
        return promise
    }
}

private extension WebhookSensor {
    convenience init(name: String, uniqueID: String, state: String) {
        self.init(name: name, uniqueID: uniqueID)
        State = state
    }
}
