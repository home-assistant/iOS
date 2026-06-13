@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

/// Tests for the cold-start pending-URL behavior that keeps a notification/deep-link URL from being
/// discarded by the automatic active-URL load (#4145).
final class WebViewControllerPendingURLTests: XCTestCase {
    // MARK: - prioritizedInlineURL

    func testPrioritizedInlineURLReturnsPendingURLWhenTargetingActiveServer() {
        let webviewURL = URL(string: "https://example.com:8123/")!
        let pending = URL(string: "https://example.com:8123/frigate/review/123")!

        let result = WebViewController.prioritizedInlineURL(pendingOpenInlineURL: pending, webviewURL: webviewURL)

        XCTAssertEqual(result, pending)
    }

    func testPrioritizedInlineURLReturnsNilWhenPendingURLTargetsDifferentServer() {
        let webviewURL = URL(string: "https://example.com:8123/")!
        let pending = URL(string: "https://other.example.com:8123/frigate")!

        let result = WebViewController.prioritizedInlineURL(pendingOpenInlineURL: pending, webviewURL: webviewURL)

        XCTAssertNil(result)
    }

    func testPrioritizedInlineURLReturnsNilWhenNoPendingURL() {
        let webviewURL = URL(string: "https://example.com:8123/")!

        let result = WebViewController.prioritizedInlineURL(pendingOpenInlineURL: nil, webviewURL: webviewURL)

        XCTAssertNil(result)
    }

    // MARK: - open(inline:) records the pending URL

    func testOpenInlineRecordsPendingURLForFrontendPath() {
        let sut = makeSUT()
        let url = URL(string: "https://example.com:8123/lovelace/default")!

        sut.open(inline: url)

        XCTAssertEqual(sut.pendingOpenInlineURL, url)
    }

    // MARK: - clearing on navigation failure

    func testRealProvisionalNavigationFailureClearsPendingURL() {
        let sut = makeSUT()
        sut.pendingOpenInlineURL = URL(string: "https://example.com:8123/frigate")!

        sut.webView(sut.webView, didFailProvisionalNavigation: nil, withError: URLError(.timedOut))

        XCTAssertNil(sut.pendingOpenInlineURL)
    }

    func testCancelledProvisionalNavigationKeepsPendingURL() {
        // A cancellation means a newer load superseded an in-flight one — clearing then would
        // revive the cold-start race, so the pending URL must survive (#4145).
        let sut = makeSUT()
        let pending = URL(string: "https://example.com:8123/frigate")!
        sut.pendingOpenInlineURL = pending

        sut.webView(sut.webView, didFailProvisionalNavigation: nil, withError: URLError(.cancelled))

        XCTAssertEqual(sut.pendingOpenInlineURL, pending)
    }

    // MARK: - loadActiveURLIfNeeded honors the pending URL (the cold-start race)

    /// Reproduces the #4145 race: on a blank (cold-start) webview, `loadActiveURLIfNeeded()` must load
    /// the pending notification URL, not the server's default URL. Without the fix this loads the
    /// default and the test fails.
    func testLoadActiveURLIfNeededPrefersPendingURLOverDefaultURL() throws {
        let wasCatalyst = Current.isCatalyst
        // Take the synchronous load path (skips the async connectivity sync used on iOS).
        Current.isCatalyst = true
        defer { Current.isCatalyst = wasCatalyst }

        let sut = makeSUT()
        let capturingWebView = CapturingWebView(
            frame: .zero,
            configuration: WebViewController.makeWebViewConfiguration()
        )
        sut.webView = capturingWebView // blank webview: `url` is nil, like a cold start

        let webviewURL = try XCTUnwrap(sut.server.info.connection.webviewURL())
        var components = try XCTUnwrap(URLComponents(url: webviewURL, resolvingAgainstBaseURL: false))
        components.path = "/frigate/review/1"
        let pending = try XCTUnwrap(components.url)
        sut.pendingOpenInlineURL = pending

        sut.loadActiveURLIfNeeded()

        let loaded = try XCTUnwrap(
            capturingWebView.loadedRequests.last?.url,
            "expected loadActiveURLIfNeeded to load a URL"
        )
        XCTAssertEqual(
            loaded.path,
            "/frigate/review/1",
            "the pending notification URL must win over the default URL on a blank webview (#4145)"
        )
    }

    // MARK: - Helpers

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: .fake())
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: .zero, configuration: WebViewController.makeWebViewConfiguration())
        return sut
    }
}

/// A `WKWebView` that records load requests instead of performing them, so tests can assert which URL
/// `WebViewController` chose without hitting the network.
private final class CapturingWebView: WKWebView {
    private(set) var loadedRequests: [URLRequest] = []

    override func load(_ request: URLRequest) -> WKNavigation? {
        loadedRequests.append(request)
        return nil
    }
}
