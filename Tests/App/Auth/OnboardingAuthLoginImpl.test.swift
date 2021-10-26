import AuthenticationServices
@testable import HomeAssistant
import PromiseKit
import XCTest

class OnboardingAuthLoginImplTests: XCTestCase {
    private var sender: UIViewController!
    private var login: OnboardingAuthLoginImpl!
    private var authDetails: OnboardingAuthDetails!

    override func setUpWithError() throws {
        try super.setUpWithError()

        FakeASWebAuthenticationSession.lastCreated = nil

        sender = UIViewController()
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
}

private class FakeASWebAuthenticationSession: ASWebAuthenticationSession {
    static var lastCreated: FakeASWebAuthenticationSession?

    let url: URL
    let scheme: String?
    let completionHandler: ASWebAuthenticationSession.CompletionHandler
    private(set) var started: Bool

    override init(
        url: URL,
        callbackURLScheme: String?,
        completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler
    ) {
        self.url = url
        self.scheme = callbackURLScheme
        self.completionHandler = completionHandler
        self.started = false
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
}
