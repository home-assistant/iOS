#if os(iOS)
import Foundation
import PromiseKit
@testable import Shared
import UIKit
import XCTest

/// `connectAPI` reschedules the periodic timer when it finishes; whether it consulted the application
/// state tells which branch of the scheduling it took.
final class PeriodicUpdateManagerTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousBackgroundTask: HomeAssistantBackgroundTaskRunner!
    private var previousIsAppExtension = false
    private var previousIsCatalyst = false
    private var previousInterval: Any?
    private var manager: PeriodicUpdateManager?

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousBackgroundTask = Current.backgroundTask
        previousIsAppExtension = Current.isAppExtension
        previousIsCatalyst = Current.isCatalyst
        previousInterval = Current.settingsStore.prefs.object(forKey: "periodicUpdateInterval")

        // No servers, so connecting resolves straight away without touching the network.
        Current.servers = FakeServerManager()
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        Current.isAppExtension = false
        Current.isCatalyst = false
        Current.settingsStore.prefs.removeObject(forKey: "periodicUpdateInterval")
    }

    override func tearDown() {
        manager?.invalidatePeriodicUpdateTimer()
        manager = nil
        Current.servers = previousServers
        Current.backgroundTask = previousBackgroundTask
        Current.isAppExtension = previousIsAppExtension
        Current.isCatalyst = previousIsCatalyst
        if let previousInterval {
            Current.settingsStore.prefs.set(previousInterval, forKey: "periodicUpdateInterval")
        } else {
            Current.settingsStore.prefs.removeObject(forKey: "periodicUpdateInterval")
        }
        super.tearDown()
    }

    func testBackgroundUpdatesAreOnlySupportedInCatalystAndExtensions() {
        XCTAssertFalse(PeriodicUpdateManager.supportsBackgroundPeriodicUpdates)

        Current.isAppExtension = true
        XCTAssertTrue(PeriodicUpdateManager.supportsBackgroundPeriodicUpdates)

        Current.isAppExtension = false
        Current.isCatalyst = true
        XCTAssertTrue(PeriodicUpdateManager.supportsBackgroundPeriodicUpdates)
    }

    func testScheduledTimerIsKeptUntilInvalidated() {
        let counter = StateQueryCounter(state: .active)
        let manager = PeriodicUpdateManager(applicationStateGetter: counter.query)
        self.manager = manager
        XCTAssertTrue(manager.applicationStateGetter() == .active)
        counter.reset()

        manager.connectAPI(reason: .periodic)
        drainMainQueue()
        XCTAssertEqual(counter.count, 1)

        // A valid timer is already scheduled, so the next connect doesn't schedule again.
        manager.connectAPI(reason: .warm)
        drainMainQueue()
        XCTAssertEqual(counter.count, 1)

        manager.invalidatePeriodicUpdateTimer()
        manager.connectAPI(reason: .cold)
        drainMainQueue()
        XCTAssertEqual(counter.count, 2)
    }

    func testBackgroundInvalidationKeepsTheTimerWhereBackgroundUpdatesAreSupported() {
        Current.isAppExtension = true
        let counter = StateQueryCounter(state: .background)
        let manager = PeriodicUpdateManager(applicationStateGetter: counter.query)
        self.manager = manager

        manager.connectAPI(reason: .background)
        drainMainQueue()

        manager.invalidatePeriodicUpdateTimer(forBackground: true)
        manager.connectAPI(reason: .background)
        drainMainQueue()

        // Background updates are supported, so the state is never consulted.
        XCTAssertEqual(counter.count, 0)
    }

    func testNothingIsScheduledWhileBackgrounded() {
        let counter = StateQueryCounter(state: .background)
        let manager = PeriodicUpdateManager(applicationStateGetter: counter.query)
        self.manager = manager

        manager.connectAPI(reason: .background)
        drainMainQueue()
        manager.connectAPI(reason: .background)
        drainMainQueue()

        // Nothing got scheduled, so each connect checked the state again.
        XCTAssertEqual(counter.count, 2)
    }

    func testNothingIsScheduledWhenPeriodicUpdatesAreDisabled() {
        Current.settingsStore.periodicUpdateInterval = nil
        let counter = StateQueryCounter(state: .active)
        let manager = PeriodicUpdateManager(applicationStateGetter: counter.query)
        self.manager = manager

        manager.connectAPI(reason: .periodic)
        drainMainQueue()
        manager.connectAPI(reason: .periodic)
        drainMainQueue()

        XCTAssertEqual(counter.count, 2)
    }

    /// PromiseKit hops to the main queue for every step of the chain; let all of them run.
    private func drainMainQueue() {
        for _ in 0 ..< 15 {
            let drained = expectation(description: "main queue drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 5)
        }
    }

    private final class StateQueryCounter {
        private let state: UIApplication.State
        private(set) var count = 0

        init(state: UIApplication.State) {
            self.state = state
        }

        func query() -> UIApplication.State {
            count += 1
            return state
        }

        func reset() {
            count = 0
        }
    }

    private final class PassthroughBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }
}
#endif
