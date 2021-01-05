import Foundation
@testable import Shared
import XCTest

class ActiveStateManagerTests: XCTestCase {
    var manager: ActiveStateManager!
    var observer: MockActiveStateObserver!
    var notificationCenter: NotificationCenter!

    override func setUp() {
        // pretend like we're in catalyst for these tests
        Current.isCatalyst = true

        notificationCenter = NotificationCenter.default
        observer = MockActiveStateObserver()
        manager = ActiveStateManager()

        manager.register(observer: observer)

        super.setUp()
    }

    override func tearDown() {
        Current.isCatalyst = false

        super.tearDown()
    }

    func testInitialStateIsActive() {
        XCTAssertTrue(manager.canTrackActiveStatus)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isFastUserSwitched)
        XCTAssertFalse(manager.states.isIdle)
        XCTAssertFalse(manager.states.isLocked)
        XCTAssertFalse(manager.states.isScreensavering)
        XCTAssertFalse(manager.states.isSleeping)
        XCTAssertFalse(manager.states.isScreenOff)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testObserverRemoval() {
        manager.unregister(observer: observer)

        notificationCenter.post(name: .init(rawValue: "com.apple.screensaver.didstart"), object: nil)
        XCTAssertFalse(observer.didUpdate)

        manager.register(observer: observer)
        notificationCenter.post(name: .init(rawValue: "com.apple.screensaver.didstop"), object: nil)
        XCTAssertTrue(observer.didUpdate)
    }

    func testScreensaver() {
        notificationCenter.post(name: .init(rawValue: "com.apple.screensaver.didstart"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isScreensavering)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "com.apple.screensaver.didstop"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isScreensavering)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testLock() {
        notificationCenter.post(name: .init(rawValue: "com.apple.screenIsLocked"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isLocked)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isLocked)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testSleep() {
        notificationCenter.post(name: .init(rawValue: "NSWorkspaceWillSleepNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isSleeping)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "NSWorkspaceDidWakeNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isSleeping)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testScreenOff() {
        notificationCenter.post(name: .init(rawValue: "NSWorkspaceScreensDidSleepNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isScreenOff)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "NSWorkspaceScreensDidWakeNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isScreenOff)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testFUS() {
        notificationCenter.post(name: .init(rawValue: "NSWorkspaceSessionDidResignActiveNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isFastUserSwitched)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "NSWorkspaceSessionDidBecomeActiveNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isFastUserSwitched)
        XCTAssertEqual(manager.idleTimer?.isValid, true)
    }

    func testTerminate() {
        notificationCenter.post(name: .init("NonMac_terminationWillBeginNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isTerminating)
        XCTAssertNil(manager.idleTimer)
    }

    func testIdleTimeWithoutAnythingElse() {
        Current.device.idleTime = { .init(value: 99, unit: .seconds) }
        manager.minimumIdleTime = .init(value: 100, unit: .seconds)
        XCTAssertNotNil(manager.idleTimer)
        manager.idleTimer?.fire()

        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isIdle)

        Current.device.idleTime = { .init(value: 100, unit: .seconds) }
        manager.idleTimer?.fire()
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isIdle)
        XCTAssertNotNil(manager.idleTimer)
        observer.reset()

        Current.device.idleTime = { .init(value: 300, unit: .seconds) }
        manager.idleTimer?.fire()
        XCTAssertFalse(observer.didUpdate, "already posted for this idle period")
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isIdle)
        XCTAssertNotNil(manager.idleTimer)
        observer.reset()

        Current.device.idleTime = { .init(value: 10, unit: .seconds) }
        manager.idleTimer?.fire()
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isIdle)
        XCTAssertNotNil(manager.idleTimer)
        observer.reset()
    }

    func testIdleTimeThenAnotherEvent() {
        Current.device.idleTime = { .init(value: 100, unit: .seconds) }
        manager.minimumIdleTime = .init(value: 100, unit: .seconds)
        XCTAssertNotNil(manager.idleTimer)
        manager.idleTimer?.fire()

        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isIdle)
        XCTAssertTrue(observer.didUpdate)

        notificationCenter.post(name: .init(rawValue: "NSWorkspaceSessionDidResignActiveNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(manager.states.isFastUserSwitched)
        XCTAssertNil(manager.idleTimer)
        observer.reset()

        notificationCenter.post(name: .init(rawValue: "NSWorkspaceSessionDidBecomeActiveNotification"), object: nil)
        XCTAssertTrue(observer.didUpdate)
        XCTAssertFalse(manager.isActive)
        XCTAssertFalse(manager.states.isFastUserSwitched)
        XCTAssertTrue(manager.states.isIdle)
        XCTAssertNotNil(manager.idleTimer)
        observer.reset()

        Current.device.idleTime = { .init(value: 99, unit: .seconds) }
        manager.idleTimer?.fire()
        XCTAssertTrue(observer.didUpdate)
        XCTAssertTrue(manager.isActive)
        XCTAssertFalse(manager.states.isIdle)
        XCTAssertNotNil(manager.idleTimer)
        observer.reset()
    }
}

class MockActiveStateObserver: ActiveStateObserver {
    var didUpdate = false

    func reset() {
        didUpdate = false
    }

    func activeStateDidChange(for manager: ActiveStateManager) {
        didUpdate = true
    }
}
