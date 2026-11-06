@testable import HomeAssistant
import XCTest

final class BackgroundRelaunchWindowSuppressorTests: XCTestCase {
    func testSharedSuppressorIsIdleWhenTheProcessWasNotRelaunched() {
        XCTAssertFalse(BackgroundRelaunchWindowSuppressor.shared.isSuppressing)
    }

    func testAutomaticMainScenesAreDestroyedWhileSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        XCTAssertTrue(suppressor.shouldDestroyMainScene(isExplicitRequest: false))
        XCTAssertTrue(suppressor.shouldDestroyMainScene(isExplicitRequest: false))
    }

    func testExplicitMainSceneRequestStopsSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        XCTAssertFalse(suppressor.shouldDestroyMainScene(isExplicitRequest: true))
        XCTAssertFalse(suppressor.isSuppressing)
        XCTAssertFalse(suppressor.shouldDestroyMainScene(isExplicitRequest: false))
    }

    func testRequestedWindowStopsSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        suppressor.windowWasRequested()
        XCTAssertFalse(suppressor.isSuppressing)
        XCTAssertFalse(suppressor.shouldDestroyMainScene(isExplicitRequest: false))
        XCTAssertFalse(suppressor.shouldDestroyRestoredScene(configurationName: "Settings"))
    }

    func testRestoredSecondaryWindowsAreDestroyedWhileSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        for activity in [SceneActivity.settings, .about, .assist, .onboarding] {
            XCTAssertTrue(suppressor.shouldDestroyRestoredScene(configurationName: activity.configurationName))
        }
        XCTAssertTrue(suppressor.shouldDestroyRestoredScene(configurationName: nil))
    }

    func testRestoredMainWindowIsLeftToItsDelegate() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: true)
        let mainWindow = SceneActivity.webView.configurationName
        XCTAssertFalse(suppressor.shouldDestroyRestoredScene(configurationName: mainWindow))
    }

    func testNothingIsDestroyedWhenNotSuppressing() {
        let suppressor = BackgroundRelaunchWindowSuppressor(isSuppressing: false)
        XCTAssertFalse(suppressor.shouldDestroyMainScene(isExplicitRequest: false))
        XCTAssertFalse(suppressor.shouldDestroyRestoredScene(configurationName: "Settings"))
    }
}
