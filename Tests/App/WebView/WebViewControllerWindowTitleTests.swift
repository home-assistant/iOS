@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct WebViewControllerWindowTitleTests {
    @Test func theWindowIsNamedAfterThePanelTheFrontendIsShowing() {
        #expect(
            WebViewController
                .windowTitle(pageTitle: "Overview – Home Assistant", serverName: "Kitchen") == "Overview"
        )
        #expect(
            WebViewController
                .windowTitle(pageTitle: "Zigbee2MQTT - Home Assistant", serverName: "Kitchen") == "Zigbee2MQTT"
        )
    }

    @Test func aFrontendOnNoPanelInParticularKeepsTheAppsOwnName() {
        #expect(WebViewController.windowTitle(pageTitle: "Home Assistant", serverName: "Kitchen") == "Home Assistant")
    }

    @Test func aPageOfItsOwnKeepsItsWholeTitle() {
        #expect(WebViewController.windowTitle(pageTitle: "Terminal", serverName: "Kitchen") == "Terminal")
    }

    @Test func aFrontendWithoutAPageTitleYetNamesTheWindowAfterItsServer() {
        #expect(WebViewController.windowTitle(pageTitle: nil, serverName: "Kitchen") == "Kitchen")
        #expect(WebViewController.windowTitle(pageTitle: "", serverName: "Kitchen") == "Kitchen")
        #expect(WebViewController.windowTitle(pageTitle: "  \n ", serverName: "Kitchen") == "Kitchen")
    }

    @Test func showingAWebViewNamesTheSceneItIsShownIn() async throws {
        try await withHostScene { scene in
            let sut = WebViewController(server: kitchenServer())
            let window = UIWindow(windowScene: scene)
            window.rootViewController = sut
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            await waitUntil { scene.title == "Kitchen" }
        }
    }

    @Test func thePageTitleTheFrontendSetsBecomesTheWindowsTitle() async throws {
        try await withHostScene { scene in
            let sut = webViewControllerParkedOnTheTestPage()
            let window = showInWindow(sut, on: scene)
            defer { window.isHidden = true }

            sut.webView.loadHTMLString(Self.overviewPage, baseURL: nil)

            await waitUntil { scene.title == "Overview" }
        }
    }

    @Test func aWindowCoveredByTheEmptyStateGoesBackToItsServersName() async throws {
        try await withHostScene { scene in
            let sut = webViewControllerParkedOnTheTestPage()
            sut.overlayState = WebFrontendOverlayState()
            let window = showInWindow(sut, on: scene)
            defer { window.isHidden = true }

            sut.webView.loadHTMLString(Self.overviewPage, baseURL: nil)
            await waitUntil { scene.title == "Overview" }

            sut.showEmptyState()
            await waitUntil { scene.title == "Kitchen" }

            sut.hideEmptyState()
            await waitUntil { scene.title == "Overview" }
        }
    }

    @Test func aWebViewHandedToAVisibleParentNamesTheScene() async throws {
        try await withHostScene { scene in
            scene.title = "Stale"
            let parent = UIViewController()
            let window = UIWindow(windowScene: scene)
            window.rootViewController = parent
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            let sut = WebViewController(server: kitchenServer())
            parent.addChild(sut)
            parent.view.addSubview(sut.view)
            sut.didMove(toParent: parent)

            await waitUntil { scene.title == "Kitchen" }
        }
    }

    @Test func aWebViewOutsideAWindowRenamesNothing() async throws {
        try await withHostScene { scene in
            scene.title = "Untouched"
            let sut = WebViewController(server: kitchenServer())
            sut.loadViewIfNeeded()

            sut.updateWindowSceneTitle()

            #expect(scene.title == "Untouched")
        }
    }

    /// `didLogOut` is what keeps the controller from navigating to its server the moment the server object
    /// updates, which would take the test page (and its title) away mid-test.
    private func webViewControllerParkedOnTheTestPage() -> WebViewController {
        let controller = WebViewController(server: kitchenServer())
        controller.didLogOut = true
        return controller
    }

    /// Hosted as a plain subview of a visible window: an appearing web view controller loads its server's
    /// URL, which would navigate away from the page under test.
    private func showInWindow(_ sut: WebViewController, on scene: UIWindowScene) -> UIWindow {
        let host = UIViewController()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.addSubview(sut.view)
        return window
    }

    private static let overviewPage =
        "<html><head><title>Overview – Home Assistant</title></head><body></body></html>"

    private func kitchenServer() -> Server {
        .fake(update: { $0.remoteName = "Kitchen" })
    }

    private func withHostScene(_ body: (UIWindowScene) async throws -> Void) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousTitle = scene.title
        defer { scene.title = previousTitle }
        try await body(scene)
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () -> Bool
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let isMet = condition()
        #expect(isMet, "condition not met within \(timeout)s", sourceLocation: sourceLocation)
    }
}
