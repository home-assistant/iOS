import Foundation
import PromiseKit
@testable import Shared
import UIKit
import XCTest

class PeriodicUpdateManagerTests: XCTestCase {
    /// Records what was asked of it instead of touching `ProcessInfo`.
    private final class RecordingBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        var names = [String]()

        func callAsFunction<PromiseValue>(
            withName name: String,
            requiringAssertion: Bool,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            names.append(name)
            return wrapping(nil)
        }
    }

    private var manager: PeriodicUpdateManager!
    private var runner: RecordingBackgroundTaskRunner!
    private var applicationState: UIApplication.State = .background

    override func setUp() {
        super.setUp()
        let previousDate = Current.date
        let previousServers = Current.servers
        let previousRunner = Current.backgroundTask
        addTeardownBlock {
            Current.date = previousDate
            Current.servers = previousServers
            Current.backgroundTask = previousRunner
        }

        setNow(Date(timeIntervalSince1970: 1_000_000))
        Current.servers = FakeServerManager()
        runner = RecordingBackgroundTaskRunner()
        Current.backgroundTask = runner
        // Reported as backgrounded unless a test says otherwise, so the `finally` of a connect,
        // which runs after the test, does not leave a periodic timer on the run loop for the
        // suites that follow.
        applicationState = .background
        manager = PeriodicUpdateManager(applicationStateGetter: { [unowned self] in applicationState })
    }

    override func tearDown() {
        manager.invalidatePeriodicUpdateTimer()
        manager = nil
        super.tearDown()
    }

    /// Lets the connects started so far run to their `finally`, which is where a periodic update
    /// gets scheduled.
    private func waitForConnectsToFinish() {
        let finished = expectation(description: "connects finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { finished.fulfill() }
        wait(for: [finished], timeout: 5)
    }

    private func setNow(_ date: Date) {
        Current.date = { date }
    }

    private func advance(by interval: TimeInterval) {
        setNow(Current.date().addingTimeInterval(interval))
    }

    /// How many connects the manager started, each of which runs under its own background task.
    private var connectCount: Int {
        runner.names.filter { $0 == BackgroundTask.connectApi.rawValue }.count
    }

    /// macOS posts `NSApplicationDidBecomeActiveNotification` twice for one activation, a few
    /// hundred milliseconds apart, so the second warm connect used to repeat the whole first one.
    func testAWarmConnectRightAfterAnotherConnectIsSkipped() {
        manager.connectAPI(reason: .warm)
        advance(by: 0.3)
        manager.connectAPI(reason: .warm)

        XCTAssertEqual(runner.names, [BackgroundTask.connectApi.rawValue])
    }

    func testAWarmConnectJustInsideTheWindowIsSkipped() {
        manager.connectAPI(reason: .periodic)
        advance(by: PeriodicUpdateManager.warmConnectDedupeWindow - 0.1)
        manager.connectAPI(reason: .warm)

        XCTAssertEqual(connectCount, 1)
    }

    func testAWarmConnectAfterTheWindowRuns() {
        manager.connectAPI(reason: .warm)
        advance(by: PeriodicUpdateManager.warmConnectDedupeWindow)
        manager.connectAPI(reason: .warm)

        XCTAssertEqual(connectCount, 2)
    }

    /// The timer reschedules itself, launch happens once, and the push extension's background
    /// connect runs in its own process, so none of them can be doubled by the system.
    func testOnlyWarmConnectsAreSkipped() {
        manager.connectAPI(reason: .periodic)
        manager.connectAPI(reason: .periodic)
        manager.connectAPI(reason: .cold)
        manager.connectAPI(reason: .background)

        XCTAssertEqual(connectCount, 4)
    }

    /// On macOS the launch activation can report warm before the cold connect that follows the
    /// network refresh. Cold still runs: it is the one that reads the refreshed network state.
    func testAColdConnectAfterAWarmOneStillRuns() {
        manager.connectAPI(reason: .warm)
        advance(by: 0.3)
        manager.connectAPI(reason: .cold)

        XCTAssertEqual(connectCount, 2)
    }

    /// The window is measured on the wall clock. Set back, the clock makes the last connect look
    /// like it is in the future, which must not read as "just now" and skip every warm connect
    /// until the clock catches up.
    func testAWarmConnectAfterTheClockWasSetBackRuns() {
        manager.connectAPI(reason: .warm)
        advance(by: -3600)
        manager.connectAPI(reason: .warm)

        XCTAssertEqual(connectCount, 2)
    }

    /// On iOS, backgrounding invalidates the periodic update and the next connect's `finally`
    /// schedules it again. A warm connect skipped for following the last one too closely has no
    /// `finally`, so it has to schedule the periodic update itself, or the foreground session
    /// that follows goes without one.
    func testASkippedWarmConnectStillSchedulesThePeriodicUpdate() {
        applicationState = .active
        manager.connectAPI(reason: .periodic)
        waitForConnectsToFinish()
        XCTAssertTrue(manager.isPeriodicUpdateScheduled)

        manager.invalidatePeriodicUpdateTimer(forBackground: true)
        XCTAssertFalse(manager.isPeriodicUpdateScheduled)

        advance(by: 0.3)
        manager.connectAPI(reason: .warm)

        XCTAssertEqual(connectCount, 1)
        XCTAssertTrue(manager.isPeriodicUpdateScheduled)
    }
}
