@testable import HomeAssistant
@testable import Shared
import SwiftUI
import XCTest

@MainActor
final class DeeplinkPresenterTests: XCTestCase {
    private var originalIsCatalyst = false

    override func setUp() {
        super.setUp()
        originalIsCatalyst = Current.isCatalyst
    }

    override func tearDown() {
        Current.isCatalyst = originalIsCatalyst
        super.tearDown()
    }

    func testPresentShowsDeeplinkViewAsSheetWithCustomDetent() throws {
        Current.isCatalyst = false
        let webView = MockWebViewController()

        DeeplinkPresenter.present(target: .page(path: "lovelace/0"), from: webView)

        XCTAssertTrue(webView.presentOverlayControllerCalled)
        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertTrue(String(describing: type(of: controller)).contains("DeeplinkView"))
        let sheet = try XCTUnwrap(controller.sheetPresentationController)
        XCTAssertEqual(sheet.detents.count, 2)
        XCTAssertEqual(sheet.selectedDetentIdentifier, .init("deeplink"))
        XCTAssertTrue(sheet.prefersGrabberVisible)
        XCTAssertFalse(sheet.prefersScrollingExpandsWhenScrolledToEdge)
    }

    func testPresentUsesFormSheetOnCatalyst() throws {
        Current.isCatalyst = true
        let webView = MockWebViewController()

        DeeplinkPresenter.present(target: .entity(id: "light.kitchen"), from: webView)

        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertEqual(controller.modalPresentationStyle, .formSheet)
    }

    func testPresentedSheetRendersAndResolvesItsDetent() throws {
        Current.isCatalyst = false
        let webView = MockWebViewController()
        DeeplinkPresenter.present(target: .page(path: "lovelace/0"), from: webView)
        let controller = try XCTUnwrap(webView.overlayedController)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.present(controller, animated: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        window.layoutIfNeeded()

        XCTAssertNotNil(controller.presentingViewController)
        root.dismiss(animated: false)
    }

    func testSheetHeightIsAFractionOfTheMaximum() {
        XCTAssertEqual(DeeplinkPresenter.sheetHeight(maximum: 1000), 700)
    }

    func testCloseActionDismissesTheOverlay() {
        let webView = MockWebViewController()

        DeeplinkPresenter.closeAction(for: webView)()

        XCTAssertTrue(webView.dismissOverlayControllerCalled)
        XCTAssertTrue(webView.dismissOverlayControllerLastAnimated)
    }
}
