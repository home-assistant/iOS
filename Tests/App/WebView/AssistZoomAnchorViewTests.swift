@testable import HomeAssistant
import UIKit
import XCTest

final class AssistZoomAnchorViewTests: XCTestCase {
    @MainActor func testInstallPinsAnchorToTopTrailingCornerOfSafeArea() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let anchor = AssistZoomAnchorView.install(in: viewController.view)
        viewController.view.layoutIfNeeded()

        // Measured against the view's own safe area: the simulator adds device insets of its own on top of
        // the ones set above.
        let safeArea = viewController.view.safeAreaInsets
        XCTAssertEqual(anchor.frame.size, AssistZoomAnchorView.size)
        XCTAssertEqual(
            anchor.frame.maxX,
            viewController.view.bounds.maxX - safeArea.right - AssistZoomAnchorView.trailingInset,
            accuracy: 0.5
        )
        XCTAssertEqual(anchor.frame.minY, safeArea.top + AssistZoomAnchorView.topInset, accuracy: 0.5)
    }

    /// The frontend's toolbar is drawn in the web view, so the anchor follows the web view's safe area —
    /// otherwise it stays at the top of the screen when iPadOS window controls push the web view down.
    @MainActor func testInstallAlignsAnchorToTheSafeAreaOfTheViewItIsAlignedTo() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 820, height: 1180))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        // Stands in for a web view pushed below the window controls.
        let webViewStandIn = UIView()
        webViewStandIn.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(webViewStandIn)
        let topOffset: CGFloat = 44
        NSLayoutConstraint.activate([
            webViewStandIn.topAnchor.constraint(equalTo: viewController.view.topAnchor, constant: topOffset),
            webViewStandIn.leftAnchor.constraint(equalTo: viewController.view.leftAnchor),
            webViewStandIn.rightAnchor.constraint(equalTo: viewController.view.rightAnchor),
            webViewStandIn.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
        ])

        let anchor = AssistZoomAnchorView.install(in: viewController.view, alignedTo: webViewStandIn)
        viewController.view.layoutIfNeeded()

        XCTAssertEqual(
            anchor.frame.minY,
            webViewStandIn.frame.minY + webViewStandIn.safeAreaInsets.top + AssistZoomAnchorView.topInset,
            accuracy: 0.5
        )
        XCTAssertGreaterThanOrEqual(anchor.frame.minY, topOffset)
    }

    @MainActor func testTouchesOverTheAnchorReachTheViewBehindIt() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let webViewStandIn = UIView(frame: viewController.view.bounds)
        viewController.view.addSubview(webViewStandIn)
        let anchor = AssistZoomAnchorView.install(in: viewController.view)
        viewController.view.layoutIfNeeded()

        // The frontend draws its own Assist button right here, so the anchor must be invisible to hit testing.
        let hitView = viewController.view.hitTest(CGPoint(x: anchor.frame.midX, y: anchor.frame.midY), with: nil)

        XCTAssertIdentical(hitView, webViewStandIn)
    }

    @MainActor func testAnchorIsInvisibleAndDoesNotTakeTouches() {
        let anchor = AssistZoomAnchorView(frame: .zero)

        // The zoom transition needs a source view that is visible and in a window, so it can't be hidden —
        // it draws nothing instead, and lets the frontend's own button underneath handle taps.
        XCTAssertFalse(anchor.isHidden)
        XCTAssertEqual(anchor.alpha, 1)
        XCTAssertEqual(anchor.backgroundColor, .clear)
        XCTAssertFalse(anchor.isUserInteractionEnabled)
    }
}
