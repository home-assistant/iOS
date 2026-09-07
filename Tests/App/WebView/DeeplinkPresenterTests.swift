@testable import HomeAssistant
import Shared
import SwiftUI
import XCTest

@MainActor
final class DeeplinkPresenterTests: XCTestCase {
    func testPresentShowsDeeplinkViewAsSheetWithCustomDetent() throws {
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
}
