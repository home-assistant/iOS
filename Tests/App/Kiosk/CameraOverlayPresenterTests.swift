import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class CameraOverlayPresenterTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousSensors: SensorContainer!
    private var kiosk: KioskModeManager!
    private var presenter: CameraOverlayPresenter!
    private var webViewController: MockWebViewController!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }
        previousSensors = Current.sensors
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()

        kiosk = KioskModeManager()
        presenter = CameraOverlayPresenter(kiosk: kiosk)
        webViewController = MockWebViewController()
    }

    override func tearDown() {
        Current.sensors = previousSensors
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

    /// Shows the camera and reports its overlay on screen, as the hosting controller does once UIKit has
    /// finished presenting it.
    @discardableResult
    private func showAndPresent(_ camera: CameraOverlayPresenter.Camera) throws -> UIViewController {
        show(camera)
        let controller = try XCTUnwrap(webViewController.overlayedController)
        presenter.overlayDidAppear(controller)
        return controller
    }

    func testShowPresentsCameraAndFlagsOverlayVisible() {
        show(frontDoor)

        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertTrue(webViewController.overlayedController is CameraOverlayHostingController)
        XCTAssertEqual(webViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testShowingTheDisplayedCameraAgainDoesNothing() throws {
        let presented = try showAndPresent(frontDoor)
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertIdentical(webViewController.overlayedController, presented)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testShowingTheDisplayedCameraAgainWhileItIsStillBeingPresentedDoesNothing() {
        show(frontDoor)
        // The web view presents on a later turn of the main queue, so it has nothing on display yet when
        // a second command for the same camera arrives right behind the first. The pending presentation
        // is what keeps the controller alive in the meantime.
        let pending = webViewController.overlayedController
        webViewController.overlayedController = nil
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
        XCTAssertNotNil(pending)
    }

    func testShowingTheDisplayedCameraAgainWhenTheWebViewReportsAnotherOverlayDoesNothing() throws {
        // Held like UIKit holds a presented controller: the camera is still on screen, but the web view
        // no longer reports it as its presented controller (its web view controller was rebuilt
        // underneath the overlay).
        let presented = try showAndPresent(frontDoor)
        webViewController.overlayedController = UIViewController()
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
        XCTAssertNotNil(presented)
    }

    func testShowingAnotherCameraReplacesTheDisplayedOne() throws {
        let presented = try showAndPresent(frontDoor)

        show(backyard)

        XCTAssertNotIdentical(webViewController.overlayedController, presented)
        XCTAssertEqual(presenter.displayedCamera, backyard)
        XCTAssertTrue(presenter.isDisplaying(backyard))
        XCTAssertFalse(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testHideDismissesTheCameraAndClearsState() throws {
        let controller = try showAndPresent(frontDoor)

        presenter.hide(on: webViewController)

        XCTAssertTrue(webViewController.dismissOverlayControllerCalled)
        XCTAssertTrue(webViewController.dismissOverlayControllerLastAnimated)

        webViewController.overlayedController = nil
        presenter.overlayDidDisappear(controller)
        webViewController.dismissOverlayControllerLastCompletion?()

        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(presenter.isDisplaying(frontDoor))
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testHideWhileTheCameraIsStillBeingPresentedWaitsForItToAppear() throws {
        show(frontDoor)
        let controller = try XCTUnwrap(webViewController.overlayedController)
        webViewController.overlayedController = nil

        presenter.hide(on: webViewController)

        // Nothing is on screen to dismiss yet, and the camera stays on record so the pending
        // presentation is not mistaken for "no camera on display".
        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)

        presenter.overlayDidAppear(controller)
        presenter.overlayDidDisappear(controller)

        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testHideWithoutCameraOnDisplayDoesNotDismissAnything() {
        kiosk.setCameraOverlayVisible(true)

        presenter.hide(on: webViewController)

        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testHideStillTakesDownACameraTheWebViewNoLongerReportsAsItsOverlay() throws {
        let controller = try showAndPresent(frontDoor)
        // The web view no longer reports the camera as its presented controller (its web view controller
        // was rebuilt underneath the overlay), yet the camera is still on screen.
        webViewController.overlayedController = UIViewController()

        presenter.hide(on: webViewController)

        // The web view's own dismissal would take down whatever it reports instead of the camera, so the
        // camera is dismissed directly; UIKit reports that dismissal on a later run loop turn.
        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        spinRunLoop("the camera overlay dismissal to complete") { presenter.displayedCamera == nil }
        XCTAssertFalse(presenter.isDisplaying(frontDoor))
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
        XCTAssertNotNil(controller)
    }

    func testHideAfterTheCameraWasReplacedByAnotherOverlayDoesNothing() throws {
        let controller = try showAndPresent(frontDoor)
        // Presenting something else over the web view dismisses the camera first, which it reports.
        presenter.overlayDidDisappear(controller)
        webViewController.overlayedController = UIViewController()
        webViewController.dismissOverlayControllerCalled = false

        presenter.hide(on: webViewController)

        XCTAssertFalse(webViewController.dismissOverlayControllerCalled)
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testOverlayDisappearingClearsStateForTheDisplayedCamera() throws {
        let controller = try showAndPresent(frontDoor)

        presenter.overlayDidDisappear(controller)

        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(presenter.isDisplaying(frontDoor))
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testOverlayDisappearingForAReplacedOverlayIsIgnored() throws {
        let first = try showAndPresent(frontDoor)
        try showAndPresent(backyard)
        try showAndPresent(frontDoor)

        // The first overlay's dismissal is reported late, after a newer overlay for the same camera
        // took its place; it must not clear the newer one's record.
        presenter.overlayDidDisappear(first)

        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testOverlayDisappearingForAnUnknownControllerIsIgnored() throws {
        try showAndPresent(frontDoor)

        presenter.overlayDidDisappear(UIViewController())

        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testSwitchingCameraInsideTheOverlayUpdatesTheDisplayedCamera() throws {
        try showAndPresent(frontDoor)
        webViewController.presentOverlayControllerCalled = false

        presenter.overlayDidSwitchCamera(to: backyard.entityId)

        XCTAssertEqual(presenter.displayedCamera, backyard)
        XCTAssertTrue(presenter.isDisplaying(backyard))
        XCTAssertFalse(presenter.isDisplaying(frontDoor))

        show(backyard)
        XCTAssertFalse(webViewController.presentOverlayControllerCalled)

        show(frontDoor)
        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
    }

    func testHostingControllerCallbacksReachThePresenter() throws {
        show(frontDoor)
        let controller = try XCTUnwrap(webViewController.overlayedController as? CameraOverlayHostingController)

        // Appearing ends the pending presentation, so a hide now goes through the web view instead of waiting.
        controller.onAppear?()
        presenter.hide(on: webViewController)
        XCTAssertTrue(webViewController.dismissOverlayControllerCalled)

        controller.onDismiss?()
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testShowAfterRecoveringFromAMissingDismissalCompletionDropsTheDeferredShow() throws {
        let controller = try showAndPresent(frontDoor)
        presenter.hide(on: webViewController)
        show(backyard)
        // The dismissal's completion never arrives, so the next show recovers by presenting directly.
        webViewController.overlayedController = nil
        presenter.overlayDidDisappear(controller)
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)
        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)

        // Dismissing that overlay must not revive the backyard camera deferred behind the first hide.
        let recovered = try XCTUnwrap(webViewController.overlayedController)
        presenter.overlayDidAppear(recovered)
        presenter.hide(on: webViewController)
        webViewController.overlayedController = nil
        presenter.overlayDidDisappear(recovered)
        webViewController.presentOverlayControllerCalled = false
        webViewController.dismissOverlayControllerLastCompletion?()

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertNil(presenter.displayedCamera)
        XCTAssertFalse(kiosk.isCameraOverlayVisible)
    }

    func testShowAfterDismissalFinishedWithoutCompletionPresents() throws {
        let controller = try showAndPresent(frontDoor)
        presenter.hide(on: webViewController)
        webViewController.overlayedController = nil
        presenter.overlayDidDisappear(controller)
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }

    func testShowWhileDismissingIsDeferredUntilDismissalCompletes() throws {
        let controller = try showAndPresent(frontDoor)
        presenter.hide(on: webViewController)
        webViewController.presentOverlayControllerCalled = false

        show(frontDoor)

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)

        webViewController.overlayedController = nil
        presenter.overlayDidDisappear(controller)
        webViewController.dismissOverlayControllerLastCompletion?()

        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(presenter.displayedCamera, frontDoor)
        XCTAssertTrue(presenter.isDisplaying(frontDoor))
        XCTAssertTrue(kiosk.isCameraOverlayVisible)
    }
}
