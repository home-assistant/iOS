@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit
import WebKit

/// The Mac status bar's actions on the web view: the page URL it hands to Safari (without the auth
/// parameter), and copy, cut and paste run against a real page with a focused, selected field.
@Suite(.sharedState)
@MainActor
struct WebViewControllerStatusBarActionsTests {
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: .fake())
        sut.isSceneActive = { _ in true }
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so nothing loads the server's URL.
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        sut.isAppInBackground = { false }
        return sut
    }

    private func load(_ html: String, baseURL: String, into sut: WebViewController) async throws {
        try sut.webView.loadHTMLString(html, baseURL: #require(URL(string: baseURL)))
        let expectation1 = await waitUntil { !sut.webView.isLoading && sut.webView.url != nil }
        #expect(expectation1)
    }

    private func evaluate(_ script: String, in webView: WKWebView) async -> Any? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }

    private func withMockOpener(_ body: (MockURLOpener) async throws -> Void) async rethrows {
        let previous = URLOpener.shared
        let opener = MockURLOpener()
        URLOpener.shared = opener
        defer { URLOpener.shared = previous }
        try await body(opener)
    }

    private func withPasteboard(_ body: () async throws -> Void) async rethrows {
        let previous = UIPasteboard.general.string
        defer { UIPasteboard.general.string = previous ?? "" }
        try await body()
    }

    @Test func thePageOpensInSafariWithoutItsAuthParameter() async throws {
        try await withMockOpener { opener in
            let sut = makeSUT()
            #expect(sut.currentPageURL == nil)
            sut.openServerInSafari()
            #expect(opener.openedURLs.isEmpty)

            try await load(
                "<html><body>Page</body></html>",
                baseURL: "https://ha.example.com/lovelace/0?external_auth=1",
                into: sut
            )
            #expect(sut.currentPageURL?.absoluteString == "https://ha.example.com/lovelace/0")

            sut.openServerInSafari()
            sut.openInBrowser()
            sut.customizeToolbar()
            sut.showFindInteraction()
            #expect(opener.openedURLs.first?.url.absoluteString == "https://ha.example.com/lovelace/0")
        }
    }

    @Test func aPageKeepsItsOtherQueryParameters() async throws {
        let sut = makeSUT()
        try await load("<html></html>", baseURL: "https://ha.example.com/map?external_auth=1&zoom=3", into: sut)
        #expect(sut.currentPageURL?.absoluteString == "https://ha.example.com/map?zoom=3")
    }

    @Test func copyCutAndPasteWorkOnTheFocusedField() async throws {
        try await withPasteboard {
            let sut = makeSUT()
            try await load(
                "<html><body><input id=\"field\" value=\"hello world\"></body></html>",
                baseURL: "https://ha.example.com/",
                into: sut
            )
            _ = await evaluate("var f = document.getElementById('field'); f.focus(); f.select(); true", in: sut.webView)

            UIPasteboard.general.string = ""
            sut.copyCurrentSelectedContent()
            let expectation2 = await waitUntil { UIPasteboard.general.string == "hello world" }
            #expect(expectation2)

            UIPasteboard.general.string = ""
            sut.cutCurrentSelectedContent()
            let expectation3 = await waitUntil { UIPasteboard.general.string == "hello world" }
            #expect(expectation3)
            // Cutting also removes the selection from the field.
            let cutEmptiesTheField = await waitForField("", in: sut.webView)
            #expect(cutEmptiesTheField)

            UIPasteboard.general.string = "pasted"
            sut.pasteContent()
            let pasteInsertsTheText = await waitForField("pasted", in: sut.webView)
            #expect(pasteInsertsTheText)

            // Nothing to paste leaves the field as it was.
            UIPasteboard.general.string = ""
            sut.pasteContent()
            let value = await evaluate("document.getElementById('field').value", in: sut.webView) as? String
            #expect(value == "pasted")
        }
    }

    /// Polls the field's value until it is `expected`, for up to ten seconds.
    private func waitForField(_ expected: String, in webView: WKWebView) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let value = await evaluate("document.getElementById('field').value", in: webView) as? String
            if value == expected {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}
