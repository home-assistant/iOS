import GRDB
@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

@MainActor
final class CameraOverlayPresenterTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var kiosk: KioskModeManager!
    private var presenter: CameraOverlayPresenter!
    private var webViewController: MockWebViewController!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }
        SensorEnablementStore.resetForTesting()

        kiosk = KioskModeManager()
        presenter = CameraOverlayPresenter(kiosk: kiosk)
        webViewController = MockWebViewController()
    }

    override func tearDown() {
        Current.database = previousDatabase
        SensorEnablementStore.resetForTesting()
        super.tearDown()
    }

    private var server: Server {
        webViewController.server
    }

    private var frontDoor: CameraOverlayPresenter.Camera {
        .init(entityId: "camera.front_door", serverIdentifier: server.identifier)
    }

    private var backyard: CameraOverlayPresenter.Camera {
        .init(entityId: "camera.backyard", serverIdentifier: server.identifier)
    }

    private func show(_ camera: CameraOverlayPresenter.Camera) {
        presenter.show(entityId: camera.entityId, server: server, on: webViewController)
    }

    func testShowPresentsCameraAndFlagsOverlayVisible() {
        show(frontDoor)

        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(webViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor, on: webViewController))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testShowingTheDisplayedCameraAgainDoesNothing() {
        show(frontDoor)
        let presented = webViewController.overlayedController
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertIdentical(webViewController.overlayedController, presented)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testShowingAnotherCameraReplacesTheDisplayedOne() {
        show(frontDoor)
        let presented = webViewController.overlayedController

        show(backyard)

        XCTAssertNotIdentical(webViewController.overlayedController, presented)
        XCTAssertEqual(presenter.displayedCamera, backyard)
        XCTAssertTrue(presenter.isDisplaying(backyard, on: webViewController))
        XCTAssertFalse(presenter.isDisplaying(frontDoor, on: webViewController))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testHideDismissesTheCameraAndClearsState() {
        show(frontDoor)

        presenter.hide(on: webViewController)

        XCTAssertTrue(webViewController.dismissOverlayControllerCalled)
        XCTAssertTrue(webViewController.dismissOverlayControllerLastAnimated)

        webViewController.overlayedController = nil
        webViewController.dismissOverlayControllerLastCompletion?()

        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(presenter.isDisplaying(frontDoor, on: webViewController))
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testHideWithoutCameraOnDisplayDoesNotDismissAnything() {
        kiosk.setCameraOverlayVisible(true)

        presenter.hide(on: webViewController)

        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testHideLeavesAnOverlayThatIsNotTheCameraAlone() {
        show(frontDoor)
        webViewController.overlayedController = UIViewController()

        presenter.hide(on: webViewController)

        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testShowWhileDismissingIsDeferredUntilDismissalCompletes() {
        show(frontDoor)
        presenter.hide(on: webViewController)
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)

        webViewController.overlayedController = nil
        webViewController.dismissOverlayControllerLastCompletion?()

        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor, on: webViewController))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }
}
