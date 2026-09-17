@testable import HomeAssistant
import Shared
import XCTest

final class StandaloneMoreInfoPresenterTests: XCTestCase {
    private var host: MockWebViewController!
    private var sut: StandaloneMoreInfoPresenter!
    private var madeControllers: [WebViewController] = []

    @MainActor override func setUp() {
        super.setUp()
        host = MockWebViewController()
        madeControllers = []
        sut = StandaloneMoreInfoPresenter(makeController: { [weak self] server, role in
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
        XCTAssertTrue(host.overlayedController is StandaloneMoreInfoPresenter.Container)
        return try XCTUnwrap(sut.sheet)
    }

    @MainActor func testPresentShowsTheFrontendPageForTheEntityAsASheet() throws {
        sut.present(entityId: "light.kitchen", from: host)

        XCTAssertTrue(host.presentOverlayControllerCalled)
        let sheet = try presentedSheet()
        XCTAssertEqual(sheet.role, .standaloneMoreInfo(entityId: "light.kitchen"))
        XCTAssertEqual(sheet.server.identifier.rawValue, host.server.identifier.rawValue)
        // The frontend underneath keeps publishing for Handoff; the sheet must not compete with it.
        XCTAssertNil(sheet.userActivity)
        XCTAssertEqual(host.onscreenEntityId, "light.kitchen")
    }

    /// The booted sheet is kept: the next entity is a page change over the bus, not a new web view.
    @MainActor func testPresentingAgainReusesTheSheetAndChangesItsPage() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(entityId: "light.bedroom", from: host)

        XCTAssertEqual(madeControllers.count, 1)
        XCTAssertTrue(try presentedSheet() === sheet)
        let handler = try sheetHandler(sheet)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(
            handler.sendExternalBusCommandWithRetryPayload?["path"] as? String,
            "/more-info?more-info-entity-id=light.bedroom"
        )
        XCTAssertEqual(host.onscreenEntityId, "light.bedroom")
    }

    /// A sheet still booting cannot change page yet; it shows the loader and is told once loaded.
    @MainActor func testPresentingWhileTheSheetBootsWaitsForItsFrontend() throws {
        sut.prewarm(from: host)
        let sheet = try XCTUnwrap(sut.sheet)
        XCTAssertEqual(sheet.role, .standaloneMoreInfo(entityId: nil))
        XCTAssertFalse(host.presentOverlayControllerCalled)

        sut.present(entityId: "light.kitchen", from: host)

        let handler = try sheetHandler(sheet)
        XCTAssertFalse(handler.sendExternalBusCommandWithRetryCalled)
        XCTAssertEqual(sut.pendingEntityId, "light.kitchen")
        XCTAssertTrue(sut.model.isLoading)

        sheet.onStandaloneFrontendLoaded?()

        XCTAssertNil(sut.pendingEntityId)
        XCTAssertFalse(sut.model.isLoading)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(
            handler.sendExternalBusCommandWithRetryPayload?["path"] as? String,
            "/more-info?more-info-entity-id=light.kitchen"
        )
    }

    @MainActor func testPrewarmBootsOnlyOneSheet() {
        sut.prewarm(from: host)
        sut.prewarm(from: host)

        XCTAssertEqual(madeControllers.count, 1)
    }

    /// Siri resolves "this" against the frontend underneath, which carries the entity only while the
    /// sheet is up.
    @MainActor func testDismissingTheSheetDropsTheEntityFromTheFrontendUnderneath() throws {
        sut.present(entityId: "light.kitchen", from: host)
        XCTAssertEqual(host.onscreenEntityId, "light.kitchen")

        sut.sheetDidDisappear()

        XCTAssertNil(host.onscreenEntityId)
    }

    /// The kept sheet moves on to another entity; dismissing it drops the one it shows now.
    @MainActor func testDismissingTheReusedSheetDropsTheEntityItShowsNow() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded
        sut.present(entityId: "light.bedroom", from: host)
        XCTAssertEqual(host.onscreenEntityId, "light.bedroom")

        sut.sheetDidDisappear()

        XCTAssertNil(host.onscreenEntityId)
    }

    /// A kept sheet is a whole second frontend, the first thing to give up when memory is short.
    @MainActor func testMemoryPressureDropsAHiddenSheet() throws {
        sut.present(entityId: "light.kitchen", from: host)
        XCTAssertNotNil(sut.sheet)

        sut.discardSheetIfHidden()

        XCTAssertNil(sut.sheet)
        sut.present(entityId: "light.kitchen", from: host)
        XCTAssertEqual(madeControllers.count, 2)
    }

    /// The bar shows what the frontend's header would: the entity's name over its area and device,
    /// with the close button where the frontend's dialog has it.
    @MainActor func testTheTopBarShowsTheTitleAndSubtitleFromTheFrontend() throws {
        sut.present(entityId: "light.kitchen", title: "Kitchen ceiling", subtitle: "Kitchen ▸ Hue bridge", from: host)

        XCTAssertTrue(host.overlayedController is StandaloneMoreInfoPresenter.Container)
        XCTAssertEqual(sut.model.title, "Kitchen ceiling")
        XCTAssertEqual(sut.model.subtitle, "Kitchen ▸ Hue bridge")
    }

    @MainActor func testTheTopBarNamesTheEntityByIdWithoutATitle() throws {
        sut.present(entityId: "light.kitchen", from: host)

        XCTAssertEqual(sut.model.title, "light.kitchen")
        XCTAssertNil(sut.model.subtitle)
    }

    /// The same bar serves every entity the kept sheet shows.
    @MainActor func testTheReusedSheetTakesTheNextEntitysTitle() throws {
        sut.present(entityId: "light.kitchen", title: "Kitchen ceiling", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(entityId: "sensor.outside", title: "Outside", subtitle: "Garden", from: host)

        XCTAssertTrue(try presentedSheet() === sheet)
        XCTAssertEqual(sut.model.title, "Outside")
        XCTAssertEqual(sut.model.subtitle, "Garden")
    }

    /// The sheet's frontend describes the bar's buttons and menu; the bar takes them over as they are.
    @MainActor func testTheFrontendsHeaderDrivesTheBar() throws {
        sut.present(entityId: "light.kitchen", title: "Kitchen ceiling", from: host)
        let sheet = try presentedSheet()

        sheet.updateStandaloneMoreInfoHeader(StandaloneMoreInfoHeader(
            entityId: "light.kitchen",
            title: "History",
            navigation: .back,
            navigationLabel: "Back to info",
            actions: [.init(id: "history", label: "History", icon: "mdi:chart-box-outline")],
            menu: [.init(id: "details", label: "Details", icon: "mdi:information-outline")]
        ))

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
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try presentedSheet()

        sut.performHeaderAction("history")

        let handler = try sheetHandler(sheet)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .moreInfoAction)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryPayload?["id"] as? String, "history")
    }

    /// A header reaching the main frontend's controller is not for any sheet.
    @MainActor func testAHeaderOnTheMainFrontendDoesNothing() {
        let main = WebViewController(server: host.server, role: .mainFrontend)
        var received: StandaloneMoreInfoHeader?
        main.onStandaloneHeaderChange = { received = $0 }

        main.updateStandaloneMoreInfoHeader(StandaloneMoreInfoHeader(entityId: "light.kitchen", title: "Kitchen"))

        XCTAssertNil(received)
    }

    /// A sensor's details fit half a screen to begin with; a drag reveals the rest.
    @MainActor func testReadOnlyDomainsStartAtAMediumDetent() throws {
        sut.present(entityId: "sensor.temperature", from: host)

        // The detents belong to the presented container, which gives the sheet its top bar.
        let presentation = try XCTUnwrap(host.overlayedController?.sheetPresentationController)
        XCTAssertEqual(presentation.detents.map(\.identifier), [.medium, .large])
        XCTAssertEqual(presentation.selectedDetentIdentifier, .medium)
        XCTAssertTrue(presentation.prefersGrabberVisible)
    }

    /// A light's controls need the whole screen, so the sheet opens large and stays so.
    @MainActor func testControlDomainsOpenLarge() throws {
        sut.present(entityId: "light.kitchen", from: host)

        let presentation = try XCTUnwrap(host.overlayedController?.sheetPresentationController)
        XCTAssertEqual(presentation.detents.map(\.identifier), [.large])
        XCTAssertEqual(presentation.selectedDetentIdentifier, .large)
        // Nothing to drag to, so no grabber.
        XCTAssertFalse(presentation.prefersGrabberVisible)
    }

    /// The same sheet serves every entity, so its size follows the entity it is about to show.
    @MainActor func testTheReusedSheetIsResizedForTheNextEntity() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try presentedSheet()
        sheet.connectionState = .loaded

        sut.present(entityId: "sensor.temperature", from: host)

        XCTAssertEqual(host.overlayedController?.sheetPresentationController?.selectedDetentIdentifier, .medium)
    }

    /// Custom domains could show anything, so they get the room.
    func testUnknownDomainsGetTheLargeSheet() {
        XCTAssertTrue(StandaloneMoreInfoPresenter.prefersCompactSheet(entityId: "binary_sensor.front_door"))
        XCTAssertFalse(StandaloneMoreInfoPresenter.prefersCompactSheet(entityId: "climate.bedroom"))
        XCTAssertFalse(StandaloneMoreInfoPresenter.prefersCompactSheet(entityId: "custom_thing.device"))
        XCTAssertFalse(StandaloneMoreInfoPresenter.prefersCompactSheet(entityId: "not-an-entity-id"))
    }

    /// A link out of the sheet goes to the frontend underneath, through the same `navigate` command
    /// the app uses for its own navigation.
    @MainActor func testNavigationOutOfTheSheetIsSentToTheFrontendUnderneath() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try presentedSheet()
        let handler = try XCTUnwrap(host.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)

        sheet.relayStandaloneNavigation(path: "/config/devices/device/abc")

        XCTAssertEqual(handler.sendExternalBusCommandWithRetryCommand, .navigate)
        XCTAssertEqual(handler.sendExternalBusCommandWithRetryPayload?["path"] as? String, "/config/devices/device/abc")
    }

    /// `more_info/navigate` only ever means the sheet; the app's frontend navigates itself.
    @MainActor func testNavigationRelayOnTheMainFrontendDoesNothing() throws {
        let main = WebViewController(server: ServerFixture.standard)
        let handler = try XCTUnwrap(host.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)

        main.relayStandaloneNavigation(path: "/config")

        XCTAssertFalse(handler.sendExternalBusCommandWithRetryCalled)
    }

    /// `more_info/close` only ever means the sheet; the app's frontend has nothing to dismiss.
    @MainActor func testCloseOnTheMainFrontendDoesNothing() {
        let main = WebViewController(server: ServerFixture.standard)

        main.closeStandaloneMoreInfo()

        XCTAssertTrue(main.role.isMainFrontend)
        XCTAssertNil(main.presentingViewController)
    }
}
