@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class WebViewControllerReauthenticationTests: XCTestCase {
    private var previousWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        previousWebsiteDataStoreHandler = Current.websiteDataStoreHandler
        Current.websiteDataStoreHandler = MockWebsiteDataStoreHandler()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        window.isHidden = true
        window.rootViewController = nil
        Current.websiteDataStoreHandler = previousWebsiteDataStoreHandler
        super.tearDown()
    }

    private func makeSUT() -> WebViewController {
        let controller = WebViewController(server: .fake(identifier: "signed-in-again"))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        return controller
    }

    /// Skips the client certificate check, which would otherwise reach out to the server first.
    private let reauthenticator = with(ServerReauthenticator()) {
        $0.clientCertificateRequirement = { _ in .value(false) }
    }

    private func presentedLogin(of controller: WebViewController) async -> OnboardingAuthLoginViewModel? {
        await waitUntil { controller.presentedViewController is UIHostingController<OnboardingAuthLoginView> }
        return (controller.presentedViewController as? UIHostingController<OnboardingAuthLoginView>)?.rootView.viewModel
    }

    func testCancellingTheLoginTakesItDown() async throws {
        let sut = makeSUT()

        sut.performReauthentication(using: .external, reauthenticator: reauthenticator)
        let presented = await presentedLogin(of: sut)
        let login = try XCTUnwrap(presented)

        login.cancel()
        await waitUntil { sut.presentedViewController == nil }

        XCTAssertNil(sut.presentedViewController)
    }

    func testATokenTheServerRefusesIsShownAsAnError() async throws {
        stub(condition: isPath("/auth/token")) { _ in
            HTTPStubsResponse(jsonObject: ["error": "invalid_grant"], statusCode: 400, headers: nil)
        }
        let sut = makeSUT()

        sut.performReauthentication(using: .external, reauthenticator: reauthenticator)
        let presented = await presentedLogin(of: sut)
        let login = try XCTUnwrap(presented)
        let callback = try XCTUnwrap(URL(string: "homeassistant://auth-callback?code=abc"))
        login
            .webView(login.webView, decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: callback))) { _ in
            }

        await waitUntil { sut.presentedViewController is UIAlertController }

        XCTAssertEqual((sut.presentedViewController as? UIAlertController)?.title, L10n.Alerts.AuthRequired.title)
    }

    func testAnAddressTheServerDoesNotHaveIsShownAsAnError() async {
        let sut = makeSUT()

        sut.performReauthentication(using: .internal, reauthenticator: reauthenticator)
        await waitUntil { sut.presentedViewController is UIAlertController }

        XCTAssertTrue(sut.presentedViewController is UIAlertController)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
