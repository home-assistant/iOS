@testable import HomeAssistant
import PromiseKit
import Shared
import XCTest

class OnboardingAuthLoginImplTests: XCTestCase {
    private var presenter: OnboardingAuthPresenter!
    private var login: OnboardingAuthLoginImpl!
    private var authDetails: OnboardingAuthDetails!

    override func setUpWithError() throws {
        try super.setUpWithError()

        presenter = OnboardingAuthPresenter()
        login = OnboardingAuthLoginImpl()

        authDetails = try OnboardingAuthDetails(baseURL: XCTUnwrap(URL(string: "http://example.com:8123")))
    }

    private func pushedViewModel() throws -> OnboardingAuthLoginViewModel {
        guard case let .login(viewModel) = presenter.pushedDestination else {
            struct NotPushed: Error {}
            XCTFail("expected a pushed login destination, got \(String(describing: presenter.pushedDestination))")
            throw NotPushed()
        }
        return viewModel
    }

    private func simulateCallback(_ viewModel: OnboardingAuthLoginViewModel, url: URL) {
        let expectation = expectation(description: "decision handler")
        viewModel.webView(
            viewModel.webViewForTests,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: url)),
            decisionHandler: { _ in expectation.fulfill() }
        )
        wait(for: [expectation], timeout: 10.0)
    }

    func testOpenPushesLoginDestination() throws {
        _ = login.open(authDetails: authDetails, presenter: presenter)
        let viewModel = try pushedViewModel()
        XCTAssertEqual(viewModel.authDetails, authDetails)
    }

    func testCancelled() throws {
        let result = login.open(authDetails: authDetails, presenter: presenter)
        let viewModel = try pushedViewModel()
        viewModel.cancel()
        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("expected cancelled, got \(error)")
            }
        }
    }

    func testInvalidURL() throws {
        let result = login.open(authDetails: authDetails, presenter: presenter)
        let viewModel = try pushedViewModel()
        try simulateCallback(viewModel, url: XCTUnwrap(URL(string: "homeassistant://auth-callback?no_code_here=true")))
        XCTAssertThrowsError(try hang(result))
    }

    func testSuccess() throws {
        let result = login.open(authDetails: authDetails, presenter: presenter)
        let viewModel = try pushedViewModel()
        try simulateCallback(viewModel, url: XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")))
        XCTAssertEqual(try hang(result).code, "code_123")
        // The flow advances by replacing the pushed destination; open() itself doesn't pop.
        XCTAssertNotNil(presenter.pushedDestination)
    }

    func testSuccessPropagatesResolvedServerURL() throws {
        let result = login.open(authDetails: authDetails, presenter: presenter)
        let viewModel = try pushedViewModel()
        // Simulate the login page being redirected to a different port before the callback.
        let redirectedURL = try XCTUnwrap(URL(string: "http://example.com:8124"))
        try simulateCallback(viewModel, url: redirectedURL)
        try simulateCallback(viewModel, url: XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")))
        let value = try hang(result)
        XCTAssertEqual(value.code, "code_123")
        XCTAssertEqual(value.resolvedURL, redirectedURL)
    }

    func testAuthDetailsNormalizeFrontendURLForAuthorizeEndpoint() throws {
        let details = try OnboardingAuthDetails(baseURL: XCTUnwrap(URL(
            string: "http://example.com:8123/lovelace/0?dashboard=main#section"
        )))

        XCTAssertEqual(details.url.scheme, "http")
        XCTAssertEqual(details.url.host, "example.com")
        XCTAssertEqual(details.url.port, 8123)
        XCTAssertEqual(details.url.path, "/auth/authorize")
        XCTAssertEqual(details.url.queryItems?["response_type"], "code")
    }
}
