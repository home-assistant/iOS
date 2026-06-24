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

    func testEachFrontendViewWiresItsControllerToItsOwnOverlayState() {
        let overlayStateA = WebFrontendOverlayState()
        let overlayStateB = WebFrontendOverlayState()

        let controllerA = FrontendView(server: Server.fake(), overlayState: overlayStateA).makeWebViewController()
        let controllerB = FrontendView(server: Server.fake(), overlayState: overlayStateB).makeWebViewController()

        XCTAssertIdentical(controllerA.overlayState, overlayStateA)
        XCTAssertIdentical(controllerB.overlayState, overlayStateB)
        XCTAssertNotIdentical(controllerA.overlayState, controllerB.overlayState)
    }

    func testFrontendViewWiresResetActionToController() {
        var resetCalled = false
        let reconnectManager = WebViewReconnectManager()

        let controller = FrontendView(
            server: Server.fake(),
            resetFrontendAction: { resetCalled = true },
            reconnectManager: reconnectManager,
            overlayState: WebFrontendOverlayState()
        ).makeWebViewController()

        controller.resetFrontendAction?()

        XCTAssertTrue(resetCalled)
        XCTAssertIdentical(controller.reconnectManager, reconnectManager)
    }
}
