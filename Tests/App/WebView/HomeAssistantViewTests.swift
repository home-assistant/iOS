@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

@MainActor
final class HomeAssistantViewTests: XCTestCase {
    func testMakeWebViewControllerUsesProvidedServerAndHasNoInitialURLWithoutRestoration() {
        let server = Server.fake()
        let representable = FrontendView(
            server: server,
            onWebViewController: { _ in },
            overlayState: WebFrontendOverlayState()
        )

        let controller = representable.makeWebViewController()

        XCTAssertIdentical(controller.server, server)
        XCTAssertNil(controller.initialURL)
    }

    func testMakeNavigationControllerHidesBarAndWrapsTheWebViewController() {
        let server = Server.fake()
        let representable = FrontendView(
            server: server,
            onWebViewController: { _ in },
            overlayState: WebFrontendOverlayState()
        )
        let webViewController = representable.makeWebViewController()

        let navigationController = FrontendView.makeNavigationController(
            rootViewController: webViewController
        )

        XCTAssertTrue(navigationController.isNavigationBarHidden)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertIdentical(navigationController.topViewController, webViewController)
    }

    func testNavigationControllerForwardsStatusBarAndHomeIndicatorPreferencesToTopController() {
        let server = Server.fake()
        let representable = FrontendView(
            server: server,
            onWebViewController: { _ in },
            overlayState: WebFrontendOverlayState()
        )
        let webViewController = representable.makeWebViewController()

        let navigationController = FrontendView.makeNavigationController(
            rootViewController: webViewController
        )

        XCTAssertIdentical(navigationController.childForStatusBarHidden, webViewController)
        XCTAssertIdentical(navigationController.childForStatusBarStyle, webViewController)
        XCTAssertIdentical(navigationController.childForHomeIndicatorAutoHidden, webViewController)
    }
}
