import Foundation
import PromiseKit
@testable import Shared
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
        // Reported as backgrounded so the `finally` of a connect, which runs after the test, does
        // not leave a periodic timer on the run loop for the suites that follow.
        manager = PeriodicUpdateManager(applicationStateGetter: { .background })
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
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
}
