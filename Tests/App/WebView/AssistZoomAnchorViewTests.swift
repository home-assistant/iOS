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

        XCTAssertEqual(anchor.frame.size, AssistZoomAnchorView.size)
        XCTAssertEqual(
            anchor.frame.maxX,
            viewController.view.bounds.maxX - AssistZoomAnchorView.trailingInset,
            accuracy: 0.5
        )
        XCTAssertEqual(anchor.frame.minY, 59 + AssistZoomAnchorView.topInset, accuracy: 0.5)
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
