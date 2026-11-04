@testable import HomeAssistant
import PromiseKit
import Shared
import WebKit
import XCTest

class OnboardingAuthLoginViewModelTests: XCTestCase {
    private var viewModel: OnboardingAuthLoginViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()

        viewModel = try .init(authDetails: .init(baseURL: URL(string: "https://www.example.com")!))
    }

    func testError() {
        viewModel.webView(viewModel.webViewForTests, didFail: nil, withError: URLError(.badServerResponse))
        XCTAssertTrue(viewModel.promise.isRejected)
    }

    func testCancelIfUnresolvedRejectsCancelled() {
        viewModel.cancelIfUnresolved()
        XCTAssertThrowsError(try hang(viewModel.promise)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("expected cancelled, got \(error)")
            }
        }
    }

    func testCancelIfUnresolvedKeepsFulfilledValue() throws {
        let url = URL(string: "homeassistant://auth-callback?code=code_123")!

        let expectation = expectation(description: "decision handler")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { _ in expectation.fulfill() }
        )
        wait(for: [expectation], timeout: 10.0)

        viewModel.cancelIfUnresolved()

        XCTAssertEqual(try hang(viewModel.promise), url)
    }

    func testDecisionHandlerWithHomeassistantScheme() {
        let url = URL(string: "homeassistant://test")!

        let expectation = expectation(description: "decision handler")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { policy in
                XCTAssertEqual(policy, .cancel)
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(try hang(viewModel.promise), url)
    }

    func testResolvedServerURLCapturedFromLastNavigation() {
        // Simulate the server redirecting the login page to a different port before the callback.
        let redirectedURL = URL(string: "http://example.com:8124/auth/authorize")!
        let httpExpectation = expectation(description: "http nav")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: redirectedURL)),
            decisionHandler: { _ in httpExpectation.fulfill() }
        )
        wait(for: [httpExpectation], timeout: 10.0)

        let callbackURL = URL(string: "homeassistant://auth-callback?code=code_123")!
        let callbackExpectation = expectation(description: "callback nav")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: callbackURL)),
            decisionHandler: { _ in callbackExpectation.fulfill() }
        )
        wait(for: [callbackExpectation], timeout: 10.0)

        // webView.url is nil in tests (no real load), so it falls back to the last navigated URL.
        XCTAssertEqual(viewModel.resolvedServerURL, redirectedURL)
        XCTAssertEqual(try hang(viewModel.promise), callbackURL)
    }

    func testDecisionHandlerWithHttpScheme() {
        let url = URL(string: "http://example.com")!

        let expectation = expectation(description: "decision handler")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { policy in
                XCTAssertEqual(policy, .allow)
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(viewModel.promise.isResolved)
    }
}

class FakeWKNavigationAction: WKNavigationAction {
    init(request: URLRequest) {
        self.overrideRequest = request
    }

    var overrideRequest: URLRequest?

    override var request: URLRequest {
        overrideRequest ?? super.request
    }
}
