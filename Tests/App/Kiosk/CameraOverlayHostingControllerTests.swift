@testable import HomeAssistant
import SwiftUI
import UIKit
import XCTest

/// Spins the run loop until `condition` holds, so UIKit can finish the presentation transitions that
/// complete asynchronously even when not animated.
@MainActor
func spinRunLoop(
    _ description: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    until condition: () -> Bool
) {
    let deadline = Date().addingTimeInterval(2)
    while !condition(), Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    XCTAssertTrue(condition(), "Timed out waiting for \(description)", file: file, line: line)
}

@MainActor
final class CameraOverlayHostingControllerTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    func testEmbeddingInAHostingControllerSupportsACustomController() {
        let standard = Color.black.embeddedInHostingController()
        let custom = Color.black.embeddedInHostingController { CameraOverlayHostingController(rootView: $0) }

        // Both variants hand back a usable controller; the custom one keeps the caller's subclass.
        standard.loadViewIfNeeded()
        custom.loadViewIfNeeded()
        XCTAssertNotNil(standard.view)
        XCTAssertNotNil(custom.view)
        XCTAssertTrue(type(of: custom) == CameraOverlayHostingController.self)
    }

    func testReportsAppearanceAndDismissalButNotBeingCoveredByAnotherPresentation() throws {
        let root = try XCTUnwrap(window.rootViewController)
        let overlay = CameraOverlayHostingController(rootView: AnyView(Color.black))
        overlay.modalPresentationStyle = .overFullScreen
        var appearances = 0
        var dismissals = 0
        overlay.onAppear = { appearances += 1 }
        overlay.onDismiss = { dismissals += 1 }

        root.present(overlay, animated: false)
        spinRunLoop("the overlay to appear") { appearances == 1 }
        XCTAssertEqual(dismissals, 0)

        // A full-screen presentation takes the overlay's view off screen without dismissing it; that is
        // the case SwiftUI's `onDisappear` cannot tell from a real dismissal.
        let cover = UIViewController()
        cover.modalPresentationStyle = .fullScreen
        overlay.present(cover, animated: false)
        spinRunLoop("the cover to be presented") { overlay.presentedViewController === cover }
        XCTAssertEqual(dismissals, 0)

        overlay.dismiss(animated: false)
        spinRunLoop("the cover to be dismissed") { overlay.presentedViewController == nil }
        XCTAssertEqual(dismissals, 0)

        root.dismiss(animated: false)
        spinRunLoop("the overlay to be dismissed") { root.presentedViewController == nil }
        XCTAssertEqual(dismissals, 1)
    }
}
