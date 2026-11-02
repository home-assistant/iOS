@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit
import WebKit

/// How the web view is pointed at a page: inline links (and the paths that belong in the browser),
/// panels and sidebar paths on a core too old to navigate through the frontend, the root, and what a
/// server version change does. Servers sit on a closed loopback port, so no load reaches a real
/// instance.
@Suite(.sharedState)
@MainActor
struct WebViewControllerNavigationTests {
    private func makeSUT(reachable: Bool = true, version: Version? = nil) -> WebViewController {
        let server = Server.fake { info in
            info.connection.set(address: reachable ? URL(string: "http://127.0.0.1:9") : nil, for: .external)
            if let version {
                info.version = version
            }
        }
        let sut = WebViewController(server: server)
        sut.isSceneActive = { _ in true }
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so nothing loads on its own.
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        sut.isAppInBackground = { false }
        sut.overlayState = WebFrontendOverlayState()
        return sut
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func withMockOpener(_ body: (MockURLOpener) async throws -> Void) async rethrows {
        let previous = URLOpener.shared
        let opener = MockURLOpener()
        URLOpener.shared = opener
        defer { URLOpener.shared = previous }
        try await body(opener)
    }

    @Test func anInlineLinkLoadsInTheWebViewUnlessItIsAnAPIPath() async throws {
        try await withMockOpener { opener in
            let sut = makeSUT()

            try sut.open(inline: #require(URL(string: "http://127.0.0.1:9/api/camera_proxy/camera.porch")))
            #expect(opener.openedURLs.count == 1)
            #expect(sut.webView.url == nil)

            let page = try #require(URL(string: "http://127.0.0.1:9/lovelace/0"))
            sut.open(inline: page)
            let expectation1 = await waitUntil { sut.webView.url?.path == "/lovelace/0" }
            #expect(expectation1)

            // The same page again with a different query is left alone when asked to.
            try sut.open(
                inline: #require(URL(string: "http://127.0.0.1:9/lovelace/0?edit=1")),
                avoidUnnecessaryReload: true
            )
            #expect(sut.webView.url?.query == nil)
        }
    }

    @Test func aPanelWithAMoreInfoDialogLoadsDirectlyOnAnOldCore() async throws {
        let sut = makeSUT()
        let url = try #require(URL(
            string: "http://127.0.0.1:9/lovelace/0?\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=light.kitchen"
        ))

        sut.openPanel(url)

        let expectation2 = await waitUntil { sut.webView.url?.path == "/lovelace/0" }
        #expect(expectation2)
    }

    @Test func aPanelFallsBackToLoadingWhenTheFrontendCannotNavigate() async throws {
        let sut = makeSUT()

        try sut.openPanel(#require(URL(string: "http://127.0.0.1:9/energy?period=day")))

        let expectation3 = await waitUntil { sut.webView.url?.path == "/energy" }
        #expect(expectation3)
    }

    @Test func aSidebarPathFallsBackToLoadingWhenTheFrontendCannotNavigate() async {
        let sut = makeSUT()

        sut.openSidebarPath("/map")

        let expectation4 = await waitUntil { sut.webView.url?.path == "/map" }
        #expect(expectation4)
    }

    @Test func goingToTheRootLoadsTheActiveURL() async {
        let sut = makeSUT()

        sut.navigateToRoot()

        let expectation5 = await waitUntil { sut.webView.url?.host == "127.0.0.1" }
        #expect(expectation5)
    }

    @Test func withoutAnActiveURLTheRootCannotBeReached() async {
        let sut = makeSUT(reachable: false)

        sut.navigateToRoot()
        sut.redirectToActiveURLRoot(failedURL: nil)
        sut.applyKioskDashboard()

        let expectation6 = await waitUntil { sut.overlayState?.showsNoActiveURL == true }
        #expect(expectation6)
        // The no-active-URL screen loads about:blank to drop any connection; whether that load has
        // committed yet is up to WebKit, so either is fine as long as no server page loads.
        #expect(sut.webView.url == nil || sut.webView.url?.absoluteString == "about:blank")
    }

    @Test func aRestoredPathThatIsNotAURLIsDropped() throws {
        let base = try #require(URL(string: "http://127.0.0.1:9"))
        #expect(WebViewController.restoredURL(base: base, relativePath: "%%%") == nil)
        #expect(
            WebViewController.restoredURL(base: base, relativePath: "/map?zoom=2#top")?.absoluteString
                == "http://127.0.0.1:9/map?zoom=2#top"
        )
    }

    @Test func aServerVersionChangeClearsTheFrontendCacheAndReloads() async {
        let previousHandler = Current.websiteDataStoreHandler
        let handler = MockWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler
        defer { Current.websiteDataStoreHandler = previousHandler }
        let sut = makeSUT()

        // Another server's change is not this controller's business.
        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: Server.fake()
        ))
        #expect(handler.cleanCacheCallCount == 0)

        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: sut.server
        ))
        #expect(handler.cleanCacheCallCount == 1)
        handler.invokePendingCompletion()
    }

    @Test func goingToTheBackgroundOnARecentCoreArmsTheReconnectTimer() {
        let old = makeSUT()
        old.scheduleReconnectBackgroundTimer()

        let recent = makeSUT(version: Version(major: 2026, minor: 1, patch: 0))
        recent.scheduleReconnectBackgroundTimer()
        #expect(recent.reconnectBackgroundTimer != nil)
        recent.reconnectBackgroundTimer?.invalidate()
    }
}
