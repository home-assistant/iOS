import Foundation
import PromiseKit
@testable import Shared
import XCTest

class SensorUpdateRetryTests: XCTestCase {
    private enum TestError: Error {
        case failed
    }

    private var scheduled: [(delay: TimeInterval, block: () -> Void)] = []
    private var performed: [[SensorProvider.Type]?] = []
    private var retry: SensorUpdateRetry!

    override func setUp() {
        super.setUp()
        Current.isAppExtension = false
        scheduled = []
        performed = []
        retry = SensorUpdateRetry { [weak self] providers in
            self?.performed.append(providers)
            return .value(())
        }
        retry.schedule = { [weak self] delay, block in
            self?.scheduled.append((delay, block))
        }
    }

    override func tearDown() {
        Current.isAppExtension = false
        retry = nil
        super.tearDown()
    }

    private func fireLastScheduled() {
        scheduled.last?.block()
    }

    private func providerNames(_ providers: [SensorProvider.Type]?) -> [String]? {
        providers?.map { String(describing: $0) }
    }

    func testAFailureSchedulesOneRetryThatReadsTheSameProviders() {
        retry.noteFailure(limitedTo: [FocusSensor.self])

        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled[0].delay, SensorUpdateRetry.delays[0])

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(providerNames(performed[0]), [String(describing: FocusSensor.self)])
    }

    /// A second failure before the retry fires widens what it reads rather than queueing another.
    func testFailuresWhileARetryIsPendingMergeIntoIt() {
        retry.noteFailure(limitedTo: [FocusSensor.self])
        retry.noteFailure(limitedTo: [BatterySensor.self])

        XCTAssertEqual(scheduled.count, 1)

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(
            providerNames(performed[0]),
            [String(describing: FocusSensor.self), String(describing: BatterySensor.self)]
        )
    }

    /// A full update that failed covers everything a limited one would have.
    func testAFullUpdateFailureAbsorbsALimitedOne() {
        retry.noteFailure(limitedTo: [FocusSensor.self])
        retry.noteFailure(limitedTo: nil)
        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertNil(performed[0])

        retry.noteFailure(limitedTo: nil)
        retry.noteFailure(limitedTo: [FocusSensor.self])
        fireLastScheduled()
        XCTAssertEqual(performed.count, 2)
        XCTAssertNil(performed[1])
    }

    /// An update that got through in the meantime carried newer values than the retry would, so
    /// the retry has nothing left to do.
    func testASuccessBeforeTheRetryFiresCancelsIt() {
        retry.noteFailure(limitedTo: nil)
        retry.noteSuccess()

        fireLastScheduled()
        XCTAssertTrue(performed.isEmpty)
    }

    /// Each failed retry waits longer than the last, up to the longest delay, which repeats until
    /// an update succeeds; a success starts the sequence over.
    func testRetriesBackOffUntilASuccessResetsThem() {
        let delays = SensorUpdateRetry.delays

        for expected in delays + [delays[delays.count - 1]] {
            retry.noteFailure(limitedTo: nil)
            XCTAssertEqual(scheduled.last?.delay, expected)
            fireLastScheduled()
        }
        XCTAssertEqual(performed.count, delays.count + 1)

        retry.noteSuccess()
        retry.noteFailure(limitedTo: nil)
        XCTAssertEqual(scheduled.last?.delay, delays[0])
    }

    /// Nothing outlives the intent an extension was launched for, so there is nothing to retry
    /// from; the app's next update reads the same stored state.
    func testNoRetryIsScheduledFromAnAppExtension() {
        Current.isAppExtension = true

        retry.noteFailure(limitedTo: nil)

        XCTAssertTrue(scheduled.isEmpty)
    }
}

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
