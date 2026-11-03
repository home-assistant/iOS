@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Every gesture action the web view can be configured with, followed through to what it asks the
/// web view to do: the keyboard shortcuts it scripts, the sidebar it opens over the bus, history
/// navigation and the server it cycles to.
@Suite(.sharedState)
@MainActor
struct WebViewGestureHandlerActionTests {
    private enum ScriptError: Error {
        case failed
    }

    private func makeSUT(server: Server = .fake()) -> (WebViewGestureHandler, MockWebViewController) {
        let webView = MockWebViewController()
        webView.server = server
        let sut = WebViewGestureHandler()
        sut.webView = webView
        return (sut, webView)
    }

    @Test(arguments: [
        (HAGestureAction.assist, WebViewJavascriptCommands.assistKeyEvent),
        (.searchEntities, WebViewJavascriptCommands.searchEntitiesKeyEvent),
        (.searchDevices, WebViewJavascriptCommands.searchDevicesKeyEvent),
        (.searchCommands, WebViewJavascriptCommands.searchCommandsKeyEvent),
        (.quickSearch, WebViewJavascriptCommands.searchEntitiesKeyEvent),
    ])
    func scriptedActionsSendTheirKeyboardShortcut(action: HAGestureAction, script: String) {
        let (sut, webView) = makeSUT()

        sut.handleGestureAction(action)

        #expect(webView.lastEvaluatedJavaScriptScript == script)
        // Both outcomes are only logged.
        webView.lastEvaluatedJavaScriptCompletion?(nil, ScriptError.failed)
        webView.lastEvaluatedJavaScriptCompletion?(true, nil)
    }

    @Test func quickSearchUsesTheNewShortcutOnRecentServers() {
        let server = Server.fake { $0.version = Version(major: 2026, minor: 3, patch: 0) }
        let (sut, webView) = makeSUT(server: server)

        sut.handleGestureAction(.quickSearch)

        #expect(webView.lastEvaluatedJavaScriptScript == WebViewJavascriptCommands.quickSearchKeyEvent)
    }

    @Test func showSidebarAsksTheFrontendOverTheBus() throws {
        let (sut, webView) = makeSUT()

        sut.handleGestureAction(.showSidebar)

        let handler = try #require(webView.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)
        #expect(handler.sendExternalBusMessage?.command == WebViewExternalBusOutgoingMessage.showSidebar.rawValue)
    }

    @Test(arguments: [false, true])
    func historyNavigationOnlyMovesWhenItCan(canMove: Bool) {
        let (sut, webView) = makeSUT()
        webView.canGoBack = canMove
        webView.canGoForward = canMove

        sut.handleGestureAction(.backPage)
        sut.handleGestureAction(.nextPage)

        #expect(webView.goBackCallCount == (canMove ? 1 : 0))
        #expect(webView.goForwardCallCount == (canMove ? 1 : 0))
        #expect(webView.evaluateJavaScriptCallCount == 0)
    }

    @Test func settingsAndDebugOpenOnTheWebView() {
        let (sut, webView) = makeSUT()

        sut.handleGestureAction(.showSettings)
        sut.handleGestureAction(.openDebug)

        #expect(webView.showSettingsCalled)
    }

    /// Registers a coordinator of the test's own as the app-wide one, so the action reaches it rather
    /// than whichever coordinator an earlier test left registered (one whose callbacks may resume a
    /// continuation that test already finished).
    @Test(arguments: [HAGestureAction.nextServer, .previousServer, .showServersList])
    func serverActionsGoThroughTheCoordinator(action: HAGestureAction) async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let servers = FakeServerManager(initial: 3)
        Current.servers = servers
        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)
        let (sut, webView) = makeSUT(server: servers.all[1])

        sut.handleGestureAction(action)

        // Whatever else reaches the app-wide coordinator meanwhile is only recorded, so this looks for
        // what this action asked for rather than at everything the coordinator saw.
        let expected: Server? = switch action {
        case .nextServer: servers.all[0]
        case .previousServer: servers.all[2]
        default: nil
        }
        let reached = await waitUntil {
            if let expected {
                coordinator.openedServers.contains { $0.identifier == expected.identifier }
            } else {
                coordinator.selectServerCallCount > 0
            }
        }
        #expect(reached)
        #expect(webView.evaluateJavaScriptCallCount == 0)
        #expect(!webView.presentOverlayControllerCalled)
    }

    /// Polls `condition` on the main actor, letting main-queue work (PromiseKit `done` blocks) run in
    /// between, until it holds or `timeout` seconds pass.
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func cyclingServersNeedsMoreThanOneServerItKnows() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let (sut, webView) = makeSUT()

        sut.handleGestureAction(.nextServer)
        sut.handleGestureAction(.previousServer)

        let orphan = WebViewGestureHandler()
        orphan.handleGestureAction(.nextServer)
        orphan.handleGestureAction(.assist)

        #expect(webView.evaluateJavaScriptCallCount == 0)
    }
}
