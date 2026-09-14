@testable import HomeAssistant
@testable import Shared
import SwiftUI
import XCTest

@MainActor
final class AppSettingsPresenterTests: XCTestCase {
    /// One presenter per scene, so every test starts from a fresh one.
    private var presenter: AppSettingsPresenter!

    override func setUp() {
        super.setUp()
        presenter = AppSettingsPresenter()
    }

    override func tearDown() {
        presenter = nil
        super.tearDown()
    }

    func testZoomSourceLastsUntilTheSheetIsDismissed() {
        presenter.presentSettings(zoomingFrom: "gear")
        XCTAssertEqual(presenter.zoomSourceID, "gear")

        presenter.isSheetPresented = false
        presenter.sheetDismissed()
        XCTAssertNil(presenter.zoomSourceID)

        presenter.presentSettings()
        XCTAssertNil(presenter.zoomSourceID)

        presenter.presentSettings(zoomingFrom: "gear")
        presenter.presentServerSelection(.init(prompt: nil, zoomsFromStandBy: false, onSelect: { _ in }))
        XCTAssertNil(presenter.zoomSourceID)
    }

    /// Where Settings goes is the scene coordinator's call (its own window on Catalyst, a sheet here), so
    /// the presenter asks it rather than presenting on its own.
    func testShowingSettingsGoesThroughTheScenesCoordinator() {
        let coordinator = MockAppCoordinator()
        presenter.appCoordinator = coordinator

        presenter.showSettings()

        XCTAssertTrue(coordinator.showSettingsCalled)
        XCTAssertFalse(presenter.isSheetPresented)
    }

    /// Before a container has claimed the presenter there is no coordinator to ask, and the sheet is still
    /// the right answer.
    func testShowingSettingsWithoutACoordinatorPresentsTheSheet() {
        presenter.showSettings()

        XCTAssertTrue(presenter.isSheetPresented)
        XCTAssertEqual(presenter.mode, .full)
    }

    func testDismissingSettingsAlsoClearsWhatItPushed() {
        presenter.isSheetPresented = true
        presenter.isPushPresented = true

        presenter.dismissSettings()

        XCTAssertFalse(presenter.isSheetPresented)
        XCTAssertFalse(presenter.isPushPresented)
    }

    func testTheEnvironmentCarriesTheScenesPresenter() {
        var values = EnvironmentValues()
        XCTAssertNil(values.appSettingsPresenter)

        values.appSettingsPresenter = presenter

        XCTAssertIdentical(values.appSettingsPresenter, presenter)
    }

    /// Dragging Settings down to the picker and choosing a server has no pending request behind it, so it
    /// activates through the scene's own coordinator rather than the app-wide one.
    func testPickingAServerWithoutARequestActivatesItOnThisScenesCoordinator() {
        let coordinator = MockAppCoordinator()
        presenter.appCoordinator = coordinator
        let server = Server.fake()

        presenter.completeServerSelection(server)

        XCTAssertEqual(coordinator.activatedServers.map(\.identifier), [server.identifier])
        XCTAssertFalse(presenter.isSheetPresented)
    }

    func testPushingSettingsPutsItAtTheRootOfThePushPath() {
        presenter.isPushPresented = true

        XCTAssertEqual(presenter.pushPath.count, 1)
        XCTAssertTrue(presenter.isPushPresented)
    }

    func testPushingSettingsAgainWhileItIsOpenDoesNotStackAnotherCopy() {
        presenter.isPushPresented = true
        presenter.pushPath.append(SettingsItem.liveActivities)

        presenter.isPushPresented = true

        // The screen Settings pushed stays put: re-asking for Settings can't push a second one over it.
        XCTAssertEqual(presenter.pushPath.count, 2)
    }

    func testClosingSettingsAlsoPopsTheScreensItPushed() {
        presenter.isPushPresented = true
        presenter.pushPath.append(SettingsItem.liveActivities)

        presenter.isPushPresented = false

        XCTAssertTrue(presenter.pushPath.isEmpty)
        XCTAssertFalse(presenter.isPushPresented)
    }

    func testPushPresentedFollowsThePathWhenTheUserNavigatesBack() {
        presenter.isPushPresented = true
        presenter.pushPath.append(SettingsItem.liveActivities)

        // Two pops, as the navigation stack would report them for two taps on Back.
        presenter.pushPath.removeLast()
        XCTAssertTrue(presenter.isPushPresented)
        presenter.pushPath.removeLast()
        XCTAssertFalse(presenter.isPushPresented)
    }
}
