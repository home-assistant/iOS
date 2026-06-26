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

    // MARK: - Gestures

    /// The set of multi-finger swipes the gesture manager installs a dedicated recognizer for — single-finger
    /// swipes (screen-edge pans) and shake (motion events) are intentionally excluded.
    func testMultiFingerSwipesCoverExactlyTheTwoAndThreeFingerSwipes() {
        XCTAssertEqual(Set(AppGesture.multiFingerSwipes), [
            ._2FingersSwipeLeft,
            ._2FingersSwipeRight,
            ._3FingersSwipeUp,
            ._3FingersSwipeLeft,
            ._3FingersSwipeRight,
        ])
    }

    func testNumberOfTouchesRequiredPerGesture() {
        XCTAssertEqual(AppGesture.swipeLeft.numberOfTouchesRequired, 1)
        XCTAssertEqual(AppGesture.swipeRight.numberOfTouchesRequired, 1)
        XCTAssertEqual(AppGesture._2FingersSwipeLeft.numberOfTouchesRequired, 2)
        XCTAssertEqual(AppGesture._2FingersSwipeRight.numberOfTouchesRequired, 2)
        XCTAssertEqual(AppGesture._3FingersSwipeUp.numberOfTouchesRequired, 3)
        XCTAssertEqual(AppGesture._3FingersSwipeLeft.numberOfTouchesRequired, 3)
        XCTAssertEqual(AppGesture._3FingersSwipeRight.numberOfTouchesRequired, 3)
        XCTAssertNil(AppGesture.shake.numberOfTouchesRequired)
    }

    /// Regression guard: a swipe recognizer keeps a fixed `AppGesture` binding (and the matching configured
    /// touch count) so the resolved action never depends on the recognizer's unreliable live `numberOfTouches`.
    func testSwipeRecognizerKeepsItsConfiguredTouchCountAndGestureBinding() throws {
        for gesture in AppGesture.multiFingerSwipes {
            let touches = try XCTUnwrap(gesture.numberOfTouchesRequired)
            let recognizer = AppSwipeGestureRecognizer(appGesture: gesture, target: nil, action: nil)
            recognizer.numberOfTouchesRequired = touches

            XCTAssertEqual(recognizer.appGesture, gesture)
            XCTAssertEqual(recognizer.numberOfTouchesRequired, touches)
        }
    }

    func testEdgePanRecognizerKeepsItsGestureBinding() {
        let left = AppScreenEdgePanGestureRecognizer(appGesture: .swipeRight, target: nil, action: nil)
        let right = AppScreenEdgePanGestureRecognizer(appGesture: .swipeLeft, target: nil, action: nil)

        XCTAssertEqual(left.appGesture, .swipeRight)
        XCTAssertEqual(right.appGesture, .swipeLeft)
    }
}
