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

    @Test func handingOverTheOverlayStateDoesNotForceTheWebViewToLoad() {
        let sut = WebViewController(server: kitchenServer())

        sut.overlayState = WebFrontendOverlayState()

        #expect(sut.viewIfLoaded == nil)
    }

    @Test func theTitleLandsOnTheSceneOfTheWindowTheWebViewIsIn() throws {
        let scene = try hostScene()
        let previousTitle = scene.title
        defer { scene.title = previousTitle }
        let sut = webViewControllerParkedOnTheTestPage()
        let window = showInWindow(sut, on: scene)
        defer { window.isHidden = true }

        sut.updateWindowSceneTitle()

        #expect(scene.title == "Kitchen")
    }

    @Test func showingAWebViewNamesTheWindowItAppearsIn() async throws {
        let scene = try hostScene()
        let sut = webViewControllerParkedOnTheTestPage()
        let titles = TitleRecorder(watching: sut)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await waitUntil { titles.last == "Kitchen" }
    }

    @Test func aWebViewHandedToAVisibleParentNamesTheWindow() throws {
        let scene = try hostScene()
        let host = UIViewController()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let sut = webViewControllerParkedOnTheTestPage()
        let titles = TitleRecorder(watching: sut)

        host.addChild(sut)
        host.view.addSubview(sut.view)
        sut.didMove(toParent: host)

        #expect(titles.last == "Kitchen")
    }

    @Test func thePageTitleTheFrontendSetsBecomesTheWindowsTitle() async throws {
        let scene = try hostScene()
        let sut = webViewControllerParkedOnTheTestPage()
        let titles = TitleRecorder(watching: sut)
        let window = showInWindow(sut, on: scene)
        defer { window.isHidden = true }

        sut.webView.loadHTMLString(Self.overviewPage, baseURL: nil)

        await waitUntil { titles.last == "Overview" }
    }

    @Test func aWindowCoveredByTheEmptyStateGoesBackToItsServersName() async throws {
        let scene = try hostScene()
        let sut = webViewControllerParkedOnTheTestPage()
        sut.overlayState = WebFrontendOverlayState()
        let titles = TitleRecorder(watching: sut)
        let window = showInWindow(sut, on: scene)
        defer { window.isHidden = true }

        sut.webView.loadHTMLString(Self.overviewPage, baseURL: nil)
        await waitUntil { titles.last == "Overview" }

        sut.showEmptyState()
        await waitUntil { titles.last == "Kitchen" }

        sut.hideEmptyState()
        await waitUntil { titles.last == "Overview" }
    }

    @Test func aWebViewOutsideAWindowRenamesNothing() {
        let sut = webViewControllerParkedOnTheTestPage()
        let titles = TitleRecorder(watching: sut)
        sut.loadViewIfNeeded()

        sut.updateWindowSceneTitle()

        #expect(titles.last == nil)
    }

    /// Collects what the controller would name its window, so that a test never has to read the title back
    /// off the single scene the whole test host shares.
    @MainActor
    private final class TitleRecorder {
        private(set) var titles: [String] = []

        var last: String? {
            titles.last
        }

        init(watching controller: WebViewController) {
            controller.applyWindowSceneTitle = { [weak self] _, title in
                self?.titles.append(title)
            }
        }
    }

    /// The real scene the test host runs in, since a `UIWindowScene` cannot be built by hand.
    private func hostScene() throws -> UIWindowScene {
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
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
