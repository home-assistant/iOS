@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// What the frontend's controller reports about its appearance, and where it puts an alert.
@MainActor
final class WebViewControllerPresentationTests: XCTestCase {
    private var window: UIWindow!
    private var sut: WebViewController!
    private var previousAppDatabaseUpdater: AppDatabaseUpdaterProtocol!
    private var previousPanelsUpdater: PanelsUpdaterProtocol!

    /// Appearing on screen refreshes the server's data, which would keep sending requests after the test.
    private final class IdleUpdater: AppDatabaseUpdaterProtocol, PanelsUpdaterProtocol {
        func stop() {}
        func update(server: Server, forceUpdate: Bool, showProgress: Bool) {}
        func update() {}
    }

    override func setUp() {
        super.setUp()
        previousAppDatabaseUpdater = Current.appDatabaseUpdater
        previousPanelsUpdater = Current.panelsUpdater
        Current.appDatabaseUpdater = IdleUpdater()
        Current.panelsUpdater = IdleUpdater()
        sut = WebViewController(server: .fake())
        // Shown in a window the controller would load the frontend, and that load would still be running
        // while later tests swap `Current.connectivity`. A logged-out controller loads nothing.
        sut.didLogOut = true
        sut.loadViewIfNeeded()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = sut
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        sut.reconnectManager?.stop()
        Current.appDatabaseUpdater = previousAppDatabaseUpdater
        Current.panelsUpdater = previousPanelsUpdater
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
