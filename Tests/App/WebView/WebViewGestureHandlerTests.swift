@testable import HomeAssistant
@testable import Shared
import SwiftUI
import XCTest

@MainActor
final class WebViewGestureHandlerTests: XCTestCase {
    func testOpenInBrowserActionAsksWebViewToOpenCurrentPageInBrowser() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.openInBrowser)

        XCTAssertTrue(webView.openInBrowserCalled)
    }

    func testNoneActionDoesNotOpenBrowser() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.none)

        XCTAssertFalse(webView.openInBrowserCalled)
    }

    func testCreateDeeplinkActionPresentsDeeplinkForCurrentPage() throws {
        let webView = MockWebViewController()
        webView.currentPageURL = URL(string: "https://home.local/lovelace/0")
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.createDeeplink)

        XCTAssertTrue(webView.presentOverlayControllerCalled)
        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertTrue(String(describing: type(of: controller)).contains("DeeplinkView"))
    }

    func testCreateDeeplinkActionWithoutCurrentPageDoesNothing() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.createDeeplink)

        XCTAssertFalse(webView.presentOverlayControllerCalled)
    }

    private func makeSUT(webView: MockWebViewController) -> WebViewGestureHandler {
        let sut = WebViewGestureHandler()
        sut.webView = webView
        return sut
    }
}
