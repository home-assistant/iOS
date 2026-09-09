@testable import HomeAssistant
import Shared
import XCTest

@MainActor
final class EntityAddToHandlerTests: XCTestCase {
    func testDeeplinkActionPresentsTheDeeplinkSheetForTheEntity() throws {
        let webView = MockWebViewController()
        let sut = EntityAddToHandler(webViewController: webView)
        let executed = expectation(description: "deeplink action executed")

        sut.execute(action: DeeplinkAction(), entityId: "light.kitchen").done {
            executed.fulfill()
        }.cauterize()
        wait(for: [executed], timeout: 10.0)

        XCTAssertTrue(webView.presentOverlayControllerCalled)
        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertTrue(String(describing: type(of: controller)).contains("DeeplinkView"))
    }
}
