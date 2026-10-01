@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// What the frontend's controller reports about its appearance, and where it puts an alert.
@MainActor
final class WebViewControllerPresentationTests: XCTestCase {
    private var window: UIWindow!
    private var sut: WebViewController!

    override func setUp() {
        super.setUp()
        // Showing the controller loads the server's address, so it is one that is refused at once rather
        // than a host the network would be asked for.
        let server = Server.fake { info in
            info.connection.set(address: URL(string: "http://127.0.0.1:1"), for: .external)
            _ = info.connection.evaluateActiveURL()
        }
        sut = WebViewController(server: server)
        sut.loadViewIfNeeded()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = sut
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        window = nil
        sut = nil
        super.tearDown()
    }

    func testAppearanceFollowsTheInterfaceStyle() {
        sut.overrideUserInterfaceStyle = .light
        XCTAssertFalse(sut.isDarkAppearance)

        sut.overrideUserInterfaceStyle = .dark
        XCTAssertTrue(sut.isDarkAppearance)
    }

    func testAnAlertIsPresentedOnTheControllerItself() {
        let alert = UIAlertController(title: "Hello", message: nil, preferredStyle: .alert)

        sut.presentAlertController(controller: alert, animated: false)

        waitForPresentation()
        XCTAssertTrue(sut.presentedViewController === alert)
        XCTAssertTrue(sut.overlayedController === alert)
    }

    /// Re-authenticating opens the login page for the server's address, and cannot be swiped away.
    func testReauthenticationPresentsTheLoginPage() {
        sut.performReauthentication(using: .external)

        waitForPresentation()
        let presented = sut.presentedViewController
        XCTAssertNotNil(presented)
        XCTAssertEqual(presented?.isModalInPresentation, true)
    }

    /// Without an address for the chosen URL type there is nothing to log in to, which the user is told.
    func testReauthenticationWithoutAnAddressExplainsItself() throws {
        sut.performReauthentication(using: .internal)

        waitForPresentation()
        let alert = try XCTUnwrap(sut.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.Alerts.AuthRequired.title)
        XCTAssertEqual(alert.actions.map(\.title), [L10n.okLabel])
    }

    private func waitForPresentation() {
        let deadline = Date().addingTimeInterval(5)
        while sut.presentedViewController == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
