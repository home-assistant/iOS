@testable import HomeAssistant
import Shared
import XCTest

final class WebViewScriptMessageHandlerTests: XCTestCase {
    private var sut: WebViewScriptMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var mockExternalMessageHandler: MockWebViewExternalMessageHandler!
    private var originalServers: ServerManager!
    private var originalCachedApis: [Identifier<Server>: HomeAssistantAPI]!

    override func setUp() async throws {
        mockWebViewController = MockWebViewController()
        mockExternalMessageHandler = MockWebViewExternalMessageHandler()
        mockWebViewController.webViewExternalMessageHandler = mockExternalMessageHandler
        sut = WebViewScriptMessageHandler()
        sut.webView = mockWebViewController
        originalServers = Current.servers
        originalCachedApis = Current.cachedApis
    }

    override func tearDown() async throws {
        sut = nil
        mockWebViewController = nil
        mockExternalMessageHandler = nil
        Current.servers = originalServers
        Current.cachedApis = originalCachedApis
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

    @MainActor func testGetExternalAuthInBackgroundWithNonStringCallbackDoesNothing() {
        sut.isAppInBackground = { true }

        sut.handle(messageName: "getExternalAuth", messageBody: ["callback": 123])

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

    /// Logging out only invalidates the credentials: the server has to stay registered so everything
    /// configured against it survives, with the user asked to log in again.
    @MainActor func testRevokeExternalAuthKeepsServerAndAsksToLogInAgain() {
        let server = givenLoggedInServer()

        let calledBack = expectation(description: "sign out callback ran")
        mockWebViewController.evaluateJavaScriptExpectation = calledBack
        sut.isAppInBackground = { false }

        sut.handle(messageName: "revokeExternalAuth", messageBody: ["callback": "window.externalBusRevoke"])

        wait(for: [calledBack], timeout: 10)
        XCTAssertEqual(mockWebViewController.lastEvaluatedJavaScriptScript, "window.externalBusRevoke(true)")
        mockWebViewController.lastEvaluatedJavaScriptCompletion?(nil, nil)

        XCTAssertEqual(Current.servers.all.map(\.identifier), [server.identifier])
        XCTAssertNotNil(Current.api(for: server))
        XCTAssertTrue(mockWebViewController.showLoggedOutStateCalled)
    }

    /// Points the environment at a single server the mock web view is showing. Its only URL refuses
    /// connections immediately, so the revoke request fails fast instead of reaching the network.
    @MainActor private func givenLoggedInServer() -> Server {
        let servers = FakeServerManager(initial: 0)
        let server = servers.addFake()
        server.update { info in
            info.connection.set(address: URL(string: "http://127.0.0.1:1")!, for: ConnectionInfo.URLType.external)
        }
        Current.servers = servers
        Current.cachedApis = [server.identifier: HomeAssistantAPI(server: server)]
        mockWebViewController.server = server
        return server
    }
}
