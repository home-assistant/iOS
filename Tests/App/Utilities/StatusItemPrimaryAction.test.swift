@testable import HomeAssistant
import XCTest

final class StatusItemPrimaryActionTests: XCTestCase {
    func testCheckForUpdatesDoesNotActivateAWebViewWindow() {
        let actions = StatusItemPrimaryAction.checkForUpdatesActions(isSupported: true, isCatalyst: true)

        XCTAssertFalse(actions.activatesWebView)
        XCTAssertTrue(actions.performsSparkleCheck)
        XCTAssertFalse(actions.opensAppStore)
    }

    func testAppStoreMacBuildOpensTheAppStoreInsteadOfSparkle() {
        let actions = StatusItemPrimaryAction.checkForUpdatesActions(isSupported: false, isCatalyst: true)

        XCTAssertFalse(actions.activatesWebView)
        XCTAssertFalse(actions.performsSparkleCheck)
        XCTAssertTrue(actions.opensAppStore)
    }
}
