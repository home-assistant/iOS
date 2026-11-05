@testable import HomeAssistant
import XCTest

final class BackgroundRelaunchWindowSuppressorTests: XCTestCase {
    func testSharedSuppressorIsIdleWhenTheProcessWasNotRelaunched() {
        XCTAssertFalse(BackgroundRelaunchWindowSuppressor.shared.isSuppressing)
    }

    func testAutomaticScenesAreDestroyedWhileSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        XCTAssertTrue(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: false))
        XCTAssertTrue(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: false))
    }

    func testUserActivityStopsSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        XCTAssertFalse(suppressor.shouldDestroyScene(hasUserActivities: true, hasURLContexts: false))
        XCTAssertFalse(suppressor.isSuppressing)
        XCTAssertFalse(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: false))
    }

    func testURLContextStopsSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        XCTAssertFalse(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: true))
        XCTAssertFalse(suppressor.isSuppressing)
    }

    func testRequestedWindowStopsSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        suppressor.windowWasRequested()
        XCTAssertFalse(suppressor.isSuppressing)
        XCTAssertFalse(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: false))
    }

    func testNothingIsDestroyedWhenNotSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: false)
        XCTAssertFalse(suppressor.shouldDestroyScene(hasUserActivities: false, hasURLContexts: false))
    }
}
