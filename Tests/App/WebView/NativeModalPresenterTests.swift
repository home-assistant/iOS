@testable import HomeAssistant
import Shared
import XCTest

final class NativeModalPresenterTests: XCTestCase {
    private var host: MockWebViewController!
    private var sut: NativeModalPresenter!
    private var madeControllers: [WebViewController] = []

    @MainActor override func setUp() {
        super.setUp()
        host = MockWebViewController()
        madeControllers = []
        sut = NativeModalPresenter(makeController: { [weak self] server, role in
            let controller = WebViewController(server: server, role: role)
            // A mock handler so a page change is observable and no JavaScript is ever run.
            controller.webViewExternalMessageHandler = MockWebViewExternalMessageHandler()
            self?.madeControllers.append(controller)
            return controller
        })
    }

    override func tearDown() {
        sut = nil
        host = nil
        madeControllers = []
        super.tearDown()
    }

    private func sheetHandler(_ sheet: WebViewController) throws -> MockWebViewExternalMessageHandler {
        try XCTUnwrap(sheet.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)
    }

    /// The web view controller inside the presented SwiftUI sheet.
    @MainActor private func presentedSheet() throws -> WebViewController {
        XCTAssertTrue(host.overlayedController is NativeModalPresenter.Container)
        return try XCTUnwrap(sut.sheet)
    }

    @MainActor func testPresentShowsTheRouteTheFrontendNamedAsAModal() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)

        XCTAssertTrue(host.presentOverlayControllerCalled)
        let sheet = try presentedSheet()
        XCTAssertEqual(sheet.role, .nativeModal(path: "/more-info?more-info-entity-id=light.kitchen"))
        XCTAssertEqual(sheet.server.identifier.rawValue, host.server.identifier.rawValue)
        // The frontend underneath keeps publishing for Handoff; the modal must not compete with it.
        XCTAssertNil(sheet.userActivity)
    }

    /// The booted modal is kept: the next route is a page change over the bus, not a new web view.
    @MainActor func testPresentingAgainReusesTheSheetAndChangesItsPage() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(path: "/more-info?more-info-entity-id=light.bedroom", from: host)

        XCTAssertEqual(madeControllers.count, 1)
        XCTAssertTrue(try presentedSheet() === sheet)
        let handler = try sheetHandler(sheet)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(
            handler.sendExternalBusCommandWithRetryPayload?["path"] as? String,
            "/more-info?more-info-entity-id=light.bedroom"
        )
    }

    /// A modal still booting cannot change page yet; it shows the loader and is told once loaded.
    @MainActor func testPresentingWhileTheSheetBootsWaitsForItsFrontend() throws {
        sut.prewarm(from: host)
        let sheet = try XCTUnwrap(sut.sheet)
        XCTAssertEqual(sheet.role, .nativeModal(path: nil))
        XCTAssertFalse(host.presentOverlayControllerCalled)

        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)

        let handler = try sheetHandler(sheet)
        XCTAssertFalse(handler.sendExternalBusCommandWithRetryCalled)
        XCTAssertEqual(sut.pendingPath, "/more-info?more-info-entity-id=light.kitchen")
        XCTAssertTrue(sut.model.isLoading)

        sheet.onNativeModalReady?()

        XCTAssertNil(sut.pendingPath)
        XCTAssertFalse(sut.model.isLoading)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(
            handler.sendExternalBusCommandWithRetryPayload?["path"] as? String,
            "/more-info?more-info-entity-id=light.kitchen"
        )
    }

    /// `frontend/loaded` arrives once per page load, so a modal whose connection dropped while it
    /// waited would keep its loader up for good if only that counted as ready.
    @MainActor func testAReconnectionAfterADroppedConnectionStillShowsTheRoute() throws {
        sut.prewarm(from: host)
        let sheet = try XCTUnwrap(sut.sheet)
        sheet.updateFrontendConnectionState(state: FrontEndConnectionState.loaded.rawValue)
        sheet.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        XCTAssertTrue(sut.model.isLoading)
        XCTAssertEqual(sut.pendingPath, "/more-info?more-info-entity-id=light.kitchen")

        sheet.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertFalse(sut.model.isLoading)
        XCTAssertNil(sut.pendingPath)
        let handler = try sheetHandler(sheet)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(
            handler.sendExternalBusCommandWithRetryPayload?["path"] as? String,
            "/more-info?more-info-entity-id=light.kitchen"
        )
    }

    /// A page inside a modal can ask for a modal of its own, and the destination of a link out of it
    /// is still the main frontend, with the stack above it dismissed.
    @MainActor func testALinkOutOfANestedModalGoesToTheMainFrontend() throws {
        let outer = MockWebViewController(role: .nativeModal(path: "/more-info?more-info-entity-id=light.kitchen"))
        let nested = NativeModalPresenter(makeController: { server, role in
            let controller = WebViewController(server: server, role: role)
            controller.webViewExternalMessageHandler = MockWebViewExternalMessageHandler()
            return controller
        })

        nested.present(path: "/more-info?more-info-entity-id=sensor.outside", from: outer)
        let sheet = try XCTUnwrap(nested.sheet)
        sheet.relayNativeModalNavigation(path: "/config/devices/device/abc")

        // Handed to the modal underneath rather than sent over its bus, which would only move the
        // page inside it.
        XCTAssertEqual(outer.relayedNativeModalNavigationPath, "/config/devices/device/abc")
        let handler = try XCTUnwrap(outer.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)
        XCTAssertFalse(handler.sendExternalBusCommandWithRetryCalled)
    }

    /// A dialog opened inside the page needs the whole screen, so the modal grows under it.
    @MainActor func testThePageCanAskForMoreRoomAfterTheModalIsUp() throws {
        sut.present(path: "/more-info?more-info-entity-id=sensor.outside", size: .compact, from: host)
        let sheet = try presentedSheet()
        let presentation = try XCTUnwrap(host.overlayedController?.sheetPresentationController)
        XCTAssertEqual(presentation.selectedDetentIdentifier, .medium)

        sheet.updateNativeModal(NativeModalUpdate(size: .full))

        XCTAssertEqual(presentation.selectedDetentIdentifier, .large)
        XCTAssertFalse(presentation.prefersGrabberVisible)
    }

    @MainActor func testPrewarmBootsOnlyOneSheet() {
        sut.prewarm(from: host)
        sut.prewarm(from: host)

        XCTAssertEqual(madeControllers.count, 1)
    }

    /// Siri resolves "this" against the frontend underneath, which carries whatever the page inside
    /// the modal reports, because the modal publishes no activity of its own.
    @MainActor func testThePageInsideGivesItsEntityToTheFrontendUnderneath() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()

        sheet.setOnscreenEntity(entityId: "light.kitchen")

        XCTAssertEqual(host.onscreenEntityId, "light.kitchen")
        // The modal keeps none of it; it has no activity to publish.
        XCTAssertNil(sheet.onscreenEntityId)
    }

    /// The entity is carried only while the modal is up.
    @MainActor func testDismissingTheModalDropsTheEntityFromTheFrontendUnderneath() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        try presentedSheet().setOnscreenEntity(entityId: "light.kitchen")

        sut.sheetDidDisappear()

        XCTAssertNil(host.onscreenEntityId)
    }

    /// The kept modal moves on to another entity; dismissing it drops the one it shows now.
    @MainActor func testDismissingTheReusedModalDropsTheEntityItShowsNow() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.setOnscreenEntity(entityId: "light.kitchen")
        sheet.connectionState = .loaded
        sut.present(path: "/more-info?more-info-entity-id=light.bedroom", from: host)
        sheet.setOnscreenEntity(entityId: "light.bedroom")
        XCTAssertEqual(host.onscreenEntityId, "light.bedroom")

        sut.sheetDidDisappear()

        XCTAssertNil(host.onscreenEntityId)
    }

    /// The sheet is laid out with the frontend's page inside it.
    @MainActor func testTheSheetLaysOutTheFrontendsPage() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", title: "Kitchen ceiling", from: host)
        let container = try XCTUnwrap(host.overlayedController as? NativeModalPresenter.Container)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = container
        window.isHidden = false
        container.view.setNeedsLayout()
        container.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil

        XCTAssertEqual(sut.model.title, "Kitchen ceiling")
    }

    /// The memory warning itself drops the hidden sheet, not just a direct call.
    @MainActor func testAMemoryWarningDropsAHiddenSheet() {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        host.overlayedController = nil
        XCTAssertNotNil(sut.sheet)

        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        let dropped = expectation(description: "sheet dropped")
        Task { @MainActor in
            dropped.fulfill()
        }
        wait(for: [dropped], timeout: 2)
        XCTAssertNil(sut.sheet)
    }

    /// A kept sheet is a whole second frontend, the first thing to give up when memory is short.
    @MainActor func testMemoryPressureDropsAHiddenSheet() {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        XCTAssertNotNil(sut.sheet)

        sut.discardSheetIfHidden()

        XCTAssertNil(sut.sheet)
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        XCTAssertEqual(madeControllers.count, 2)
    }

    /// The bar shows what the frontend's header would: the entity's name over its area and device,
    /// with the close button where the frontend's dialog has it.
    @MainActor func testTheTopBarShowsTheTitleAndSubtitleFromTheFrontend() {
        sut.present(
            path: "/more-info?more-info-entity-id=light.kitchen",
            title: "Kitchen ceiling",
            subtitle: "Kitchen ▸ Hue bridge",
            from: host
        )

        XCTAssertTrue(host.overlayedController is NativeModalPresenter.Container)
        XCTAssertEqual(sut.model.title, "Kitchen ceiling")
        XCTAssertEqual(sut.model.subtitle, "Kitchen ▸ Hue bridge")
    }

    @MainActor func testTheTopBarNamesTheRouteWithoutATitle() {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)

        XCTAssertEqual(sut.model.title, "/more-info?more-info-entity-id=light.kitchen")
        XCTAssertNil(sut.model.subtitle)
    }

    /// The same bar serves every route the kept modal shows.
    @MainActor func testTheReusedModalTakesTheNextTitle() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", title: "Kitchen ceiling", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(
            path: "/more-info?more-info-entity-id=sensor.outside",
            title: "Outside",
            subtitle: "Garden",
            from: host
        )

        XCTAssertTrue(try presentedSheet() === sheet)
        XCTAssertEqual(sut.model.title, "Outside")
        XCTAssertEqual(sut.model.subtitle, "Garden")
    }

    /// The sheet's frontend describes the bar's buttons and menu; the bar takes them over as they are.
    @MainActor func testTheFrontendsHeaderDrivesTheBar() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", title: "Kitchen ceiling", from: host)
        let sheet = try presentedSheet()

        sheet.updateNativeModal(NativeModalUpdate(header: NativeModalHeader(
            title: "History",
            navigation: .back,
            navigationLabel: "Back to info",
            actions: [.init(id: "history", label: "History", icon: "mdi:chart-box-outline")],
            menu: [.init(id: "details", label: "Details", icon: "mdi:information-outline")]
        )))

        XCTAssertEqual(sut.model.title, "History")
        XCTAssertNil(sut.model.subtitle)
        XCTAssertEqual(sut.model.navigation, .back)
        XCTAssertEqual(sut.model.navigationLabel, "Back to info")
        XCTAssertEqual(sut.model.actions.map(\.id), ["history"])
        XCTAssertEqual(sut.model.menu.map(\.id), ["details"])
    }

    /// A tap on the bar is not acted on here: the sheet's frontend is told which item, and does what
    /// its own button would have.
    @MainActor func testATapOnTheBarIsSentToTheSheetsFrontend() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()

        sut.performHeaderAction("history")

        let handler = try sheetHandler(sheet)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .modalAction)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryPayload?["id"] as? String, "history")
    }

    /// A header reaching the main frontend's controller is not for any sheet.
    @MainActor func testAHeaderOnTheMainFrontendDoesNothing() {
        let main = WebViewController(server: host.server, role: .mainFrontend)
        var received: NativeModalUpdate?
        main.onNativeModalUpdate = { received = $0 }

        main.updateNativeModal(NativeModalUpdate(header: NativeModalHeader(title: "Kitchen")))

        XCTAssertNil(received)
    }

    /// A compact modal opens at half a screen; a drag reveals the rest.
    @MainActor func testACompactModalStartsAtAMediumDetent() throws {
        sut.present(path: "/more-info?more-info-entity-id=sensor.temperature", size: .compact, from: host)

        // The detents belong to the presented container, which gives the sheet its top bar.
        let presentation = try XCTUnwrap(host.overlayedController?.sheetPresentationController)
        XCTAssertEqual(presentation.detents.map(\.identifier), [.medium, .large])
        XCTAssertEqual(presentation.selectedDetentIdentifier, .medium)
        XCTAssertTrue(presentation.prefersGrabberVisible)
    }

    /// A full modal needs the whole screen, so it opens large and stays so.
    @MainActor func testAFullModalOpensLarge() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)

        let presentation = try XCTUnwrap(host.overlayedController?.sheetPresentationController)
        XCTAssertEqual(presentation.detents.map(\.identifier), [.large])
        XCTAssertEqual(presentation.selectedDetentIdentifier, .large)
        // Nothing to drag to, so no grabber.
        XCTAssertFalse(presentation.prefersGrabberVisible)
    }

    /// The same modal serves every route, so its size follows the one it is about to show.
    @MainActor func testTheReusedModalIsResizedForTheNextRoute() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(path: "/more-info?more-info-entity-id=sensor.temperature", size: .compact, from: host)

        XCTAssertEqual(host.overlayedController?.sheetPresentationController?.selectedDetentIdentifier, .medium)
    }

    /// A link out of the sheet goes to the frontend underneath, through the same `navigate` command
    /// the app uses for its own navigation.
    @MainActor func testNavigationOutOfTheSheetIsSentToTheFrontendUnderneath() throws {
        sut.present(path: "/more-info?more-info-entity-id=light.kitchen", from: host)
        let sheet = try presentedSheet()
        let handler = try XCTUnwrap(host.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)

        sheet.relayNativeModalNavigation(path: "/config/devices/device/abc")

        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryPayload?["path"] as? String, "/config/devices/device/abc")
    }

    /// `modal/navigate` only ever means a modal; the app's frontend navigates itself.
    @MainActor func testNavigationRelayOnTheMainFrontendDoesNothing() throws {
        let main = WebViewController(server: ServerFixture.standard)
        let handler = try XCTUnwrap(host.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)

        main.relayNativeModalNavigation(path: "/config")

        XCTAssertFalse(handler.sendExternalBusCommandWithRetryCalled)
    }

    /// `modal/close` only ever means a modal; the app's frontend has nothing to dismiss.
    @MainActor func testCloseOnTheMainFrontendDoesNothing() {
        let main = WebViewController(server: ServerFixture.standard)

        main.closeNativeModal()

        XCTAssertTrue(main.role.isMainFrontend)
        XCTAssertNil(main.presentingViewController)
    }
}
