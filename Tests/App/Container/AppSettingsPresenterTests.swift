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
}
