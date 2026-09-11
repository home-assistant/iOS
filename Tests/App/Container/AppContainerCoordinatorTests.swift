@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

@MainActor
final class AppContainerCoordinatorTests: XCTestCase {
    private var server: Server!
    private var window: UIWindow!
    private var frontend: MockWebFrontend!
    private var coordinator: AppContainerCoordinator!

    override func setUp() {
        super.setUp()
        server = Server.fake()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        frontend = MockWebFrontend(server: server, presentationWindow: window)
        coordinator = AppContainerCoordinator()
        coordinator.setFrontend(frontend)
    }

    override func tearDown() {
        AppSettingsPresenter.shared.isSheetPresented = false
        AppSettingsPresenter.shared.isPushPresented = false
        AppSettingsPresenter.shared.sheetDismissed()
        super.tearDown()
    }

    func testDismissPresentedContentClearsSwiftUIPresentationStateAndCallsCompletion() {
        AppSettingsPresenter.shared.isSheetPresented = true
        var completed = false

        coordinator.dismissPresentedContent { completed = true }

        XCTAssertFalse(AppSettingsPresenter.shared.isSheetPresented)
        XCTAssertTrue(completed)
    }

    func testDismissPresentedContentClearsTheFrontendsOwnOverlaysWhenNothingIsPresentedAtTheRoot() {
        coordinator.dismissPresentedContent(completion: nil)

        XCTAssertEqual(frontend.dismissOverlayControllerCallCount, 1)
    }

    func testDeepLinkNavigatesTheFrontendWhileASheetIsPresented() {
        AppSettingsPresenter.shared.isSheetPresented = true
        let navigated = expectation(description: "frontend navigated")
        frontend.onOpen = { _ in navigated.fulfill() }

        coordinator.open(
            from: .deeplink,
            server: server,
            urlString: "/lovelace/dashboard",
            skipConfirm: true,
            isComingFromAppIntent: false
        )

        wait(for: [navigated], timeout: 5)
        XCTAssertEqual(frontend.openedInlineURLs.last?.path, "/lovelace/dashboard")
        XCTAssertTrue(frontend.openedPanelURLs.isEmpty)
        XCTAssertFalse(AppSettingsPresenter.shared.isSheetPresented)
    }

    func testAppIntentOpensThePanelWhileASheetIsPresented() {
        AppSettingsPresenter.shared.isSheetPresented = true
        let navigated = expectation(description: "frontend navigated")
        frontend.onOpen = { _ in navigated.fulfill() }

        coordinator.open(
            from: .deeplink,
            server: server,
            urlString: "/lovelace/dashboard",
            skipConfirm: true,
            isComingFromAppIntent: true
        )

        wait(for: [navigated], timeout: 5)
        XCTAssertEqual(frontend.openedPanelURLs.last?.path, "/lovelace/dashboard")
        XCTAssertTrue(frontend.openedInlineURLs.isEmpty)
        XCTAssertFalse(AppSettingsPresenter.shared.isSheetPresented)
    }

    func testActivatingTheActiveServerSendsTheFrontendBackToTheRoot() {
        var openedServer: Server?
        coordinator.onOpenServer = { openedServer = $0 }

        coordinator.activate(server: server)

        XCTAssertEqual(frontend.navigateToRootCallCount, 1)
        XCTAssertNil(openedServer)
    }

    func testActivatingAnotherServerOpensItWithoutNavigatingTheOutgoingFrontend() {
        let otherServer = Server.fake()
        var openedServer: Server?
        coordinator.onOpenServer = { openedServer = $0 }

        coordinator.activate(server: otherServer)

        XCTAssertEqual(openedServer?.identifier, otherServer.identifier)
        XCTAssertEqual(frontend.navigateToRootCallCount, 0)
    }

    func testSelectingAServerClearsWhatIsAlreadyPresentedFirst() {
        AppSettingsPresenter.shared.isSheetPresented = true

        coordinator.selectServer(prompt: nil) { _ in }

        // The picker is the settings sheet itself, so what is on screen goes away synchronously and the
        // picker takes its place a runloop later.
        XCTAssertFalse(AppSettingsPresenter.shared.isSheetPresented)

        let presented = expectation(description: "picker presented")
        DispatchQueue.main.async { presented.fulfill() }
        wait(for: [presented], timeout: 5)

        XCTAssertTrue(AppSettingsPresenter.shared.isSheetPresented)
    }
}
