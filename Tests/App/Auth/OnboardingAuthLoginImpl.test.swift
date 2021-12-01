import AuthenticationServices
@testable import HomeAssistant
import PromiseKit
import Shared
import XCTest

class OnboardingAuthLoginImplTests: XCTestCase {
    private var sender: FakeUIViewController!
    private var login: OnboardingAuthLoginImpl!
    private var authDetails: OnboardingAuthDetails!

    override func setUpWithError() throws {
        try super.setUpWithError()

        FakeASWebAuthenticationSession.lastCreated = nil

        sender = FakeUIViewController()
        login = OnboardingAuthLoginImpl()
        login.authenticationSessionClass = FakeASWebAuthenticationSession.self

        authDetails = try OnboardingAuthDetails(baseURL: try XCTUnwrap(URL(string: "http://example.com:8123")))
    }

    private func assertConfigured(
        _ session: FakeASWebAuthenticationSession,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(session.started, file: file, line: line)
        if #available(iOS 13, *) {
            XCTAssertNotNil(session.presentationContextProvider, file: file, line: line)
        }
    }

    func testCancelled() throws {
        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        assertConfigured(session)
        session.completionHandler(nil, ASWebAuthenticationSessionError(.canceledLogin, userInfo: [:]))
        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("expected cancelled, got \(error)")
            }
        }
    }

    func testInvalidURL() throws {
        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        assertConfigured(session)
        session.completionHandler(try XCTUnwrap(URL(string: "homeassistant://auth-callback?no_code_here=true")), nil)
        XCTAssertThrowsError(try hang(result))
    }

    func testSuccess() throws {
        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        assertConfigured(session)
        session.completionHandler(try XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")), nil)
        XCTAssertEqual(try hang(result), "code_123")
    }

    func testAlertOnMacCancelled() throws {
        Current.isCatalyst = true

        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        assertConfigured(session)

        let timer = try XCTUnwrap(login.macPresentTimer)
        timer.fire()
        let alert = try XCTUnwrap(sender.presentedViewController as? UIAlertController)
        let cancel = try XCTUnwrap(alert.actions.first(where: { $0.style == .cancel }))
        cancel.ha_handler(cancel)
        XCTAssertTrue(session.isCancelled)
        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("expected cancelled, got \(error)")
            }
        }
    }

    func testAlertOnMacCancelledBeforeTimer() throws {
        Current.isCatalyst = true

        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        assertConfigured(session)

        session.cancel()

        let expectation = expectation(description: "one run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 10.0)

        let timer = try XCTUnwrap(login.macPresentTimer)
        timer.fire()

        XCTAssertNil(sender.presentedViewController)

        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("expected cancelled, got \(error)")
            }
        }
    }

    func testAlertOnMacSuccessBeforeTimer() throws {
        Current.isCatalyst = true

        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        let timer = try XCTUnwrap(login.macPresentTimer)

        session.completionHandler(try XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")), nil)

        XCTAssertEqual(try hang(result), "code_123")
        timer.fire()

        let expectation = expectation(description: "one run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNil(sender.presentedViewController)
    }

    func testAlertOnMacSuccessAfterTimer() throws {
        Current.isCatalyst = true

        let result = login.open(authDetails: authDetails, sender: sender)
        let session = try XCTUnwrap(FakeASWebAuthenticationSession.lastCreated)
        let timer = try XCTUnwrap(login.macPresentTimer)

        // we want it to show
        timer.fire()

        XCTAssertNotNil(sender.presentedViewController as? UIAlertController)

        session.completionHandler(try XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")), nil)
        XCTAssertEqual(try hang(result), "code_123")

        let expectation = expectation(description: "one run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNil(sender.presentedViewController)
    }
}

private class FakeUIViewController: UIViewController {
    private var backingPresentedViewController: UIViewController?
    override var presentedViewController: UIViewController? {
        backingPresentedViewController
    }

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        backingPresentedViewController = viewControllerToPresent
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        backingPresentedViewController = nil
        super.dismiss(animated: flag, completion: completion)
    }
}

private class FakeASWebAuthenticationSession: ASWebAuthenticationSession {
    static var lastCreated: FakeASWebAuthenticationSession?

    let url: URL
    let scheme: String?
    let completionHandler: ASWebAuthenticationSession.CompletionHandler
    private(set) var started: Bool
    private(set) var isCancelled: Bool

    override init(
        url: URL,
        callbackURLScheme: String?,
        completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler
    ) {
        self.url = url
        self.scheme = callbackURLScheme
        self.completionHandler = completionHandler
        self.started = false
        self.isCancelled = false
        super.init(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
        Self.lastCreated = self
    }

    override func start() -> Bool {
        if started {
            XCTFail("should not be invoked more than once")
        }
        started = true
        return true
    }

    override func cancel() {
        isCancelled = true
        completionHandler(nil, ASWebAuthenticationSessionError(.canceledLogin))
    }
}
