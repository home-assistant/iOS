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
    private var themeModeApplier: FrontendThemeModeApplier!
    /// The presenter of the coordinator's own scene, as `ContainerView` hands it over.
    private var presenter: AppSettingsPresenter!

    override func setUp() {
        super.setUp()
        server = Server.fake()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        frontend = MockWebFrontend(server: server, presentationWindow: window)
        themeModeApplier = FrontendThemeModeApplier(windowScenes: { [] })
        presenter = AppSettingsPresenter()
        coordinator = AppContainerCoordinator(themeModeApplier: themeModeApplier)
        coordinator.settingsPresenter = presenter
        coordinator.setFrontend(frontend)
    }

    override func tearDown() {
        presenter = nil
        super.tearDown()
    }

    func testDismissPresentedContentClearsSwiftUIPresentationStateAndCallsCompletion() {
        presenter.isSheetPresented = true
        var completed = false

        coordinator.dismissPresentedContent { completed = true }

        XCTAssertFalse(presenter.isSheetPresented)
        XCTAssertTrue(completed)
    }

    func testDismissPresentedContentClearsTheFrontendsOwnOverlaysWhenNothingIsPresentedAtTheRoot() {
        coordinator.dismissPresentedContent(completion: nil)

        XCTAssertEqual(frontend.dismissOverlayControllerCallCount, 1)
    }

    func testDeepLinkNavigatesTheFrontendWhileASheetIsPresented() {
        presenter.isSheetPresented = true
        let navigated = expectation(description: "frontend navigated")
        frontend.onOpen = { _ in navigated.fulfill() }

        coordinator.open(
            from: .deeplink,
            server: server,
            urlString: "/lovelace/dashboard",
            skipConfirm: true,
            isComingFromAppIntent: false
        )

        wait(for: [navigated], timeout: 30)
        XCTAssertEqual(frontend.openedInlineURLs.last?.path, "/lovelace/dashboard")
        XCTAssertTrue(frontend.openedPanelURLs.isEmpty)
        XCTAssertFalse(presenter.isSheetPresented)
    }

    func testAppIntentOpensThePanelWhileASheetIsPresented() {
        presenter.isSheetPresented = true
        let navigated = expectation(description: "frontend navigated")
        frontend.onOpen = { _ in navigated.fulfill() }

        coordinator.open(
            from: .deeplink,
            server: server,
            urlString: "/lovelace/dashboard",
            skipConfirm: true,
            isComingFromAppIntent: true
        )

        wait(for: [navigated], timeout: 30)
        XCTAssertEqual(frontend.openedPanelURLs.last?.path, "/lovelace/dashboard")
        XCTAssertTrue(frontend.openedInlineURLs.isEmpty)
        XCTAssertFalse(presenter.isSheetPresented)
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
        presenter.isSheetPresented = true

        coordinator.selectServer(prompt: nil) { _ in }

        // The picker is the settings sheet itself, so what is on screen goes away synchronously and the
        // picker takes its place a runloop later.
        XCTAssertFalse(presenter.isSheetPresented)

        waitUntil { presenter.isSheetPresented }

        XCTAssertTrue(presenter.isSheetPresented)
    }

    func testSelectingAServerOnlyOpensThePickerInTheSceneThatAskedForIt() {
        // A second window, with the presenter and frontend its own container owns.
        let otherScenePresenter = AppSettingsPresenter()
        let otherFrontend = MockWebFrontend(server: server)
        let otherCoordinator = AppContainerCoordinator(themeModeApplier: themeModeApplier)
        otherCoordinator.settingsPresenter = otherScenePresenter
        otherCoordinator.setFrontend(otherFrontend)

        coordinator.selectServer(prompt: nil) { _ in }
        waitUntil { presenter.isSheetPresented }

        XCTAssertFalse(otherScenePresenter.isSheetPresented)
    }

    /// Spins the main run loop until `condition` holds. `selectServer` clears the screen and only then
    /// hops to present, so the picker can take more than the one turn a single `async` would cover.
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "Timed out spinning the main run loop", file: file, line: line)
    }

    func testTheSceneShowingAFrontendFollowsThatServersThemeMode() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let applier = FrontendThemeModeApplier(windowScenes: { [scene] })
        let sceneWindow = UIWindow(windowScene: scene)
        defer { scene.windows.forEach { $0.overrideUserInterfaceStyle = .unspecified } }

        // Both held: the coordinator keeps only a weak frontend, and it is what resolves the scene.
        let sceneFrontend = MockWebFrontend(server: server, presentationWindow: sceneWindow)
        let sceneCoordinator = AppContainerCoordinator(themeModeApplier: applier)
        sceneCoordinator.setFrontend(sceneFrontend)

        applier.setMode(.dark, for: server.identifier)
        // Another scene switching server must not take this one with it.
        applier.setMode(.light, for: .init(rawValue: "another-scene"))

        XCTAssertTrue(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
    }
}
