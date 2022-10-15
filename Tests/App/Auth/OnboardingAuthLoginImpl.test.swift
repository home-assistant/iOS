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

        FakeOnboardingAuthLoginViewController.lastCreated = nil

        sender = FakeUIViewController()
        login = OnboardingAuthLoginImpl()
        login.loginViewControllerClass = FakeOnboardingAuthLoginViewController.self

        authDetails = try OnboardingAuthDetails(baseURL: try XCTUnwrap(URL(string: "http://example.com:8123")))
    }

    func testCancelled() throws {
        let result = login.open(authDetails: authDetails, sender: sender)
        let viewController = try XCTUnwrap(FakeOnboardingAuthLoginViewController.lastCreated)
        viewController.resolver.reject(PMKError.cancelled)
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
        let viewController = try XCTUnwrap(FakeOnboardingAuthLoginViewController.lastCreated)
        viewController.resolver.fulfill(try XCTUnwrap(URL(string: "homeassistant://auth-callback?no_code_here=true")))
        XCTAssertThrowsError(try hang(result))
    }

    func testSuccess() throws {
        let result = login.open(authDetails: authDetails, sender: sender)
        let viewController = try XCTUnwrap(FakeOnboardingAuthLoginViewController.lastCreated)
        viewController.resolver.fulfill(try XCTUnwrap(URL(string: "homeassistant://auth-callback?code=code_123")))
        XCTAssertEqual(try hang(result), "code_123")
    }
}

private class FakeUIViewController: UIViewController {
    private var backingPresentedViewController: UIViewController?
    override var presentedViewController: UIViewController? {
        backingPresentedViewController
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        backingPresentedViewController = nil
        super.dismiss(animated: flag, completion: completion)
    }
}

private final class FakeOnboardingAuthLoginViewController: UIViewController, OnboardingAuthLoginViewController {
    static var lastCreated: FakeOnboardingAuthLoginViewController?

    let resolver: Resolver<URL>
    let promise: Promise<URL>

    required init(authDetails: OnboardingAuthDetails) {
        (self.promise, self.resolver) = Promise<URL>.pending()
        super.init(nibName: nil, bundle: nil)
        Self.lastCreated = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
