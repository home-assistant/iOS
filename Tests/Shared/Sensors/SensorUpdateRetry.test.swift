import Foundation
import PromiseKit
@testable import Shared
import XCTest

class SensorUpdateRetryTests: XCTestCase {
    /// Records what was asked of it instead of touching `ProcessInfo`.
    private final class RecordingBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        var names = [String]()

        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            names.append(name)
            return wrapping(nil)
        }
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

    private func providerNames(_ providers: [SensorProvider.Type]?) -> Set<String>? {
        providers.map { Set($0.map { String(describing: $0) }) }
    }

    private func names(_ providers: [SensorProvider.Type]) -> Set<String> {
        Set(providers.map { String(describing: $0) })
    }

    /// A failed update, as the API reports it: numbered when it started, failed afterwards.
    private func fail(limitedTo providers: [SensorProvider.Type]?) -> UInt64 {
        let generation = retry.beginUpdate()
        retry.noteFailure(generation: generation, limitedTo: providers)
        return generation
    }

    private func succeed(limitedTo providers: [SensorProvider.Type]?) {
        retry.noteSuccess(generation: retry.beginUpdate(), limitedTo: providers)
    }

    func testAFailureSchedulesOneRetryThatReadsTheSameProviders() {
        _ = fail(limitedTo: [FocusSensor.self])

        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled[0].delay, SensorUpdateRetry.delays[0])

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(providerNames(performed[0]), names([FocusSensor.self]))
    }

    /// A second failure before the retry fires widens what it reads rather than queueing another.
    func testFailuresWhileARetryIsPendingMergeIntoIt() {
        _ = fail(limitedTo: [FocusSensor.self])
        _ = fail(limitedTo: [BatterySensor.self])

        XCTAssertEqual(scheduled.count, 1)

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(providerNames(performed[0]), names([FocusSensor.self, BatterySensor.self]))
    }

    /// A full update that failed covers everything a limited one would have, whichever came first.
    func testAFullUpdateFailureAbsorbsALimitedOne() {
        _ = fail(limitedTo: [FocusSensor.self])
        _ = fail(limitedTo: nil)
        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertNil(performed[0])

        succeed(limitedTo: nil)
        _ = fail(limitedTo: nil)
        _ = fail(limitedTo: [FocusSensor.self])
        fireLastScheduled()
        XCTAssertEqual(performed.count, 2)
        XCTAssertNil(performed[1])
    }

    /// An update that got through in the meantime carried newer values than the retry would, so
    /// the retry has nothing left to do.
    func testASuccessBeforeTheRetryFiresCancelsIt() {
        _ = fail(limitedTo: nil)
        succeed(limitedTo: nil)

        fireLastScheduled()
        XCTAssertTrue(performed.isEmpty)
    }

    /// A limited update getting through says nothing about the sensors it didn't carry: a full
    /// update that failed is still owed its retry.
    func testALimitedSuccessDoesNotCancelAFullRetry() {
        _ = fail(limitedTo: nil)
        succeed(limitedTo: [FocusSensor.self])

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertNil(performed[0])
    }

    /// Only the sensors the successful update carried drop out of the retry.
    func testALimitedSuccessNarrowsTheRetryToTheRest() {
        _ = fail(limitedTo: [FocusSensor.self, BatterySensor.self])
        succeed(limitedTo: [FocusSensor.self])

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(providerNames(performed[0]), names([BatterySensor.self]))
    }

    /// Requests don't resolve in the order they started: one that read its values before a newer
    /// run failed can't stand in for it, so its late success leaves that retry in place.
    func testAnOlderSuccessDoesNotCancelANewerFailure() {
        let older = retry.beginUpdate()
        _ = fail(limitedTo: nil)
        retry.noteSuccess(generation: older, limitedTo: nil)

        fireLastScheduled()
        XCTAssertEqual(performed.count, 1)

        let olderLimited = retry.beginUpdate()
        _ = fail(limitedTo: [FocusSensor.self])
        retry.noteSuccess(generation: olderLimited, limitedTo: [FocusSensor.self])
        fireLastScheduled()
        XCTAssertEqual(performed.count, 2)
    }

    /// Each failed retry waits longer than the last, up to the longest delay, which repeats until
    /// an update succeeds; a success starts the sequence over.
    func testRetriesBackOffUntilASuccessResetsThem() {
        let delays = SensorUpdateRetry.delays

        for expected in delays + [delays[delays.count - 1]] {
            _ = fail(limitedTo: nil)
            XCTAssertEqual(scheduled.last?.delay, expected)
            fireLastScheduled()
        }
        XCTAssertEqual(performed.count, delays.count + 1)

        succeed(limitedTo: nil)
        _ = fail(limitedTo: nil)
        XCTAssertEqual(scheduled.last?.delay, delays[0])
    }

    /// Nothing outlives the intent an extension was launched for, so there is nothing to retry
    /// from; the app's next update reads the same stored state.
    func testNoRetryIsScheduledFromAnAppExtension() {
        Current.isAppExtension = true

        _ = fail(limitedTo: nil)

        XCTAssertTrue(scheduled.isEmpty)
    }

    /// A short wait is held open by a background task so it survives the app being backgrounded;
    /// a long one isn't, since a suspended app can't run it anyway.
    func testShortWaitsAreHeldOpenByABackgroundTask() {
        let runner = RecordingBackgroundTaskRunner()
        let previousRunner = Current.backgroundTask
        Current.backgroundTask = runner
        addTeardownBlock { Current.backgroundTask = previousRunner }

        let held = expectation(description: "held wait ran")
        SensorUpdateRetry.wait(0.05, holdingBackgroundTask: true) { held.fulfill() }
        wait(for: [held], timeout: 5)
        XCTAssertEqual(runner.names, [BackgroundTask.sensorUpdateRetry.rawValue])

        let plain = expectation(description: "plain wait ran")
        SensorUpdateRetry.wait(0.05, holdingBackgroundTask: false) { plain.fulfill() }
        wait(for: [plain], timeout: 5)
        XCTAssertEqual(runner.names.count, 1)
    }

    /// The default scheduler decides by the delay alone.
    func testTheDefaultScheduleHoldsOnlyShortDelays() {
        let runner = RecordingBackgroundTaskRunner()
        let previousRunner = Current.backgroundTask
        Current.backgroundTask = runner
        addTeardownBlock { Current.backgroundTask = previousRunner }

        let ran = expectation(description: "scheduled block ran")
        SensorUpdateRetry { _ in .value(()) }.schedule(0.05) { ran.fulfill() }
        wait(for: [ran], timeout: 5)
        XCTAssertEqual(runner.names, [BackgroundTask.sensorUpdateRetry.rawValue])
    }
}
