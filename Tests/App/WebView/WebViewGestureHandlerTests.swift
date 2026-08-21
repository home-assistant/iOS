@testable import HomeAssistant
@testable import Shared
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

    private func makeSUT(webView: MockWebViewController) -> WebViewGestureHandler {
        let sut = WebViewGestureHandler()
        sut.webView = webView
        return sut
    }
}
