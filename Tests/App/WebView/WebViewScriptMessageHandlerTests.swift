@testable import HomeAssistant
import Shared
import XCTest

final class WebViewScriptMessageHandlerTests: XCTestCase {
    private var sut: WebViewScriptMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var mockExternalMessageHandler: MockWebViewExternalMessageHandler!

    override func setUp() async throws {
        mockWebViewController = MockWebViewController()
        mockExternalMessageHandler = MockWebViewExternalMessageHandler()
        mockWebViewController.webViewExternalMessageHandler = mockExternalMessageHandler
        sut = WebViewScriptMessageHandler()
        sut.webView = mockWebViewController
    }

    override func tearDown() async throws {
        sut = nil
        mockWebViewController = nil
        mockExternalMessageHandler = nil
    }

    @MainActor func testGetExternalAuthInBackgroundRejectsCallback() {
        sut.isAppInBackground = { true }

        sut.handle(messageName: "getExternalAuth", messageBody: ["callback": "window.externalAuthSetToken"])

        XCTAssertEqual(
            mockWebViewController.lastEvaluatedJavaScriptScript,
            "window.externalAuthSetToken(false, 'Token unavailable')"
        )
    }

    @MainActor func testGetExternalAuthInBackgroundWithoutCallbackDoesNothing() {
        sut.isAppInBackground = { true }

        sut.handle(messageName: "getExternalAuth", messageBody: ["force": false])

        XCTAssertFalse(mockWebViewController.evaluateJavaScriptCalled)
    }

    @MainActor func testExternalBusInBackgroundIsIgnored() {
        sut.isAppInBackground = { true }

        sut.handle(messageName: "externalBus", messageBody: ["id": 1])

        XCTAssertFalse(mockExternalMessageHandler.handleExternalMessageCalled)
        XCTAssertFalse(mockWebViewController.evaluateJavaScriptCalled)
    }

    @MainActor func testExternalBusInForegroundIsHandled() {
        sut.isAppInBackground = { false }

        sut.handle(messageName: "externalBus", messageBody: ["id": 1])

        XCTAssertTrue(mockExternalMessageHandler.handleExternalMessageCalled)
        XCTAssertEqual(mockExternalMessageHandler.handleExternalMessageParams?["id"] as? Int, 1)
    }
}
