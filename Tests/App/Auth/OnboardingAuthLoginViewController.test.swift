@testable import HomeAssistant
import PromiseKit
import Shared
import WebKit
import XCTest

class OnboardingAuthLoginViewControllerImplTests: XCTestCase {
    private var controller: OnboardingAuthLoginViewControllerImpl!

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init(authDetails: try .init(baseURL: URL(string: "https://www.example.com")!))
    }

    func testError() {
        controller.webView(controller.webViewForTests, didFail: nil, withError: URLError(.badServerResponse))
        XCTAssertTrue(controller.promise.isRejected)
    }

    func testDecisionHandlerWithHomeassistantScheme() {
        let url = URL(string: "homeassistant://test")!

        let expectation = expectation(description: "decision handler")
        controller.webView(
            controller.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { policy in
                XCTAssertEqual(policy, .cancel)
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(try hang(controller.promise), url)
    }

    func testDecisionHandlerWithHttpScheme() {
        let url = URL(string: "http://example.com")!

        let expectation = expectation(description: "decision handler")
        controller.webView(
            controller.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { policy in
                XCTAssertEqual(policy, .allow)
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(controller.promise.isResolved)
    }
}

private class FakeWKNavigationAction: WKNavigationAction {
    init(request: URLRequest) {
        self.overrideRequest = request
    }

    var overrideRequest: URLRequest?

    override var request: URLRequest {
        overrideRequest ?? super.request
    }
}
