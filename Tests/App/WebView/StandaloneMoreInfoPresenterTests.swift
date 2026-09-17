@testable import HomeAssistant
import Shared
import XCTest

final class StandaloneMoreInfoPresenterTests: XCTestCase {
    private var host: MockWebViewController!
    private var sut: StandaloneMoreInfoPresenter!

    override func setUp() {
        super.setUp()
        host = MockWebViewController()
        sut = StandaloneMoreInfoPresenter()
    }

    override func tearDown() {
        sut = nil
        host = nil
        super.tearDown()
    }

    @MainActor func testPresentShowsTheFrontendPageForTheEntityAsASheet() throws {
        sut.present(entityId: "light.kitchen", from: host)

        XCTAssertTrue(host.presentOverlayControllerCalled)
        let sheet = try XCTUnwrap(host.overlayedController as? WebViewController)
        XCTAssertEqual(sheet.role, .standaloneMoreInfo(entityId: "light.kitchen"))
        XCTAssertEqual(sheet.server.identifier.rawValue, host.server.identifier.rawValue)
        // The frontend underneath keeps publishing for Handoff; the sheet must not compete with it.
        XCTAssertNil(sheet.userActivity)
        XCTAssertEqual(host.onscreenEntityId, "light.kitchen")
    }

    /// Siri resolves "this" against the frontend underneath, which carries the entity only while the
    /// sheet is up.
    @MainActor func testDismissingTheSheetDropsTheEntityFromTheFrontendUnderneath() throws {
        sut.present(entityId: "light.kitchen", from: host)
        XCTAssertEqual(host.onscreenEntityId, "light.kitchen")

        let sheet = try XCTUnwrap(host.overlayedController as? WebViewController)
        sheet.onDismiss?()

        XCTAssertNil(host.onscreenEntityId)
    }

    /// A late dismissal callback for the entity before must not take the newer entity down with it.
    @MainActor func testDismissingForAnOlderEntityKeepsTheNewerOne() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try XCTUnwrap(host.overlayedController as? WebViewController)
        let firstDismiss = sheet.onDismiss
        sut.present(entityId: "light.bedroom", from: host)

        firstDismiss?()

        XCTAssertEqual(host.onscreenEntityId, "light.bedroom")
    }

    /// A link out of the sheet goes to the frontend underneath, through the same `navigate` command
    /// the app uses for its own navigation.
    @MainActor func testNavigationOutOfTheSheetIsSentToTheFrontendUnderneath() throws {
        sut.present(entityId: "light.kitchen", from: host)
        let sheet = try XCTUnwrap(host.overlayedController as? WebViewController)
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
