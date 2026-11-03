@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit
import WebKit

/// The `WebViewControllerProtocol` surface the external bus and gestures drive: history, scripts,
/// banners, overlays and in-frontend navigation, against a server on a closed loopback port so no
/// load ever reaches a real instance.
@MainActor
struct WebViewControllerProtocolConformanceTests {
    private final class RecordingBannerPresenter: BannerPresenter {
        private(set) var shownIDs: [String] = []
        private(set) var hiddenIDs: [String] = []

        func show(on viewController: UIViewController, request: BannerRequest) {
            shownIDs.append(request.id)
        }

        func hide(id: String) {
            hiddenIDs.append(id)
        }
    }

    private func makeSUT() -> WebViewController {
        let server = Server.fake { info in
            info.connection.set(address: URL(string: "http://127.0.0.1:9"), for: .external)
        }
        let sut = WebViewController(server: server)
        sut.isSceneActive = { _ in true }
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        sut.isAppInBackground = { false }
        return sut
    }

    /// What these tests wait for lands through the main queue, which other suites keep busy under
    /// load, so the deadline counts main-queue turns as well as time.
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        await LoadTolerantDeadline.waitUntil(condition)
    }

    @Test func historyFollowsTheWebViewAndStopsOnceRetired() {
        let sut = makeSUT()
        #expect(!sut.canGoBack)
        #expect(!sut.canGoForward)
        sut.goBack()
        sut.goForward()

        sut.isRetired = true
        sut.goBack()
        sut.goForward()
        sut.load(request: URLRequest(url: URL(string: "http://127.0.0.1:9/lovelace")!))
        #expect(sut.webView.url == nil)
    }

    @Test func scriptsRunInTheWebView() async {
        let sut = makeSUT()
        let result: Any? = await withCheckedContinuation { continuation in
            sut.evaluateJavaScript("1 + 1") { result, _ in
                continuation.resume(returning: result)
            }
        }
        #expect(result as? Int == 2)
        sut.makeWebViewFirstResponder()
    }

    @Test func bannersGoThroughThePresenter() {
        let sut = makeSUT()
        let presenter = RecordingBannerPresenter()
        sut.bannerPresenter = presenter

        sut.showBanner(request: BannerRequest(
            id: "banner",
            title: nil,
            message: "Hello",
            duration: .forever,
            dimming: .none,
            style: .warning
        ))
        sut.hideBanner(id: "banner")

        #expect(presenter.shownIDs == ["banner"])
        #expect(presenter.hiddenIDs == ["banner"])
    }

    @Test func overlaysWithNothingPresentedAreHarmless() async {
        let sut = makeSUT()
        #expect(sut.overlayedController == nil)

        sut.dismissControllerAboveOverlayController()
        var dismissed = false
        sut.dismissOverlayController(animated: false) { dismissed = true }
        let expectation1 = await waitUntil { dismissed }
        #expect(expectation1)

        sut.presentAlertController(
            controller: UIAlertController(title: "t", message: nil, preferredStyle: .alert),
            animated: false
        )
        for _ in 0 ..< 3 {
            await Task.yield()
        }
    }

    @Test func navigatingToAPathLoadsItOnTheActiveURL() async {
        let sut = makeSUT()

        sut.navigateToPath(path: "/lovelace/1")

        let expectation2 = await waitUntil { sut.webView.url?.path == "/lovelace/1" }
        #expect(expectation2)
        #expect(sut.webView.url?.host == "127.0.0.1")
    }

    @Test func refreshingWhileConnectedDoesNothing() {
        let sut = makeSUT()
        sut.connectionState = .connected
        sut.refreshIfDisconnected()
        #expect(sut.webView.url == nil)
    }
}
