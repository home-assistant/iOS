@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

@MainActor
final class NotificationManagerKioskCameraTests: XCTestCase {
    private var webViewController: WebViewController!
    private var manager: NotificationManager!

    override func setUp() {
        super.setUp()
        webViewController = WebViewController(server: .fake())
        webViewController.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
        Current.sceneManager.setWebViewController(webViewController)
        CameraOverlayPresenter.shared.hide(on: webViewController)
        manager = NotificationManager()
    }

    override func tearDown() {
        CameraOverlayPresenter.shared.hide(on: webViewController)
        super.tearDown()
    }

    func testShowCameraCommandDisplaysCameraOnTheFrontendServer() {
        manager.openCamera(from: ["entity_id": "camera.front_door"])

        waitUntil("camera displayed") {
            CameraOverlayPresenter.shared.displayedCamera?.entityId == "camera.front_door"
        }
        XCTAssertEqual(
            CameraOverlayPresenter.shared.displayedCamera?.serverIdentifier,
            webViewController.server.identifier
        )
        XCTAssertTrue(Current.kiosk.isCameraOverlayVisible)
    }

    func testShowCameraCommandReadsEntityFromHomeAssistantPayload() {
        manager.openCamera(from: ["homeassistant": ["entity_id": "camera.backyard"]])

        waitUntil("camera displayed") {
            CameraOverlayPresenter.shared.displayedCamera?.entityId == "camera.backyard"
        }
    }

    func testShowCameraCommandWithoutCameraEntityIsIgnored() {
        manager.openCamera(from: ["entity_id": "light.kitchen"])
        manager.openCamera(from: nil)
        pumpMainQueue()

        XCTAssertNil(CameraOverlayPresenter.shared.displayedCamera)
        XCTAssertFalse(Current.kiosk.isCameraOverlayVisible)
    }

    func testHideCameraCommandClearsDisplayedCamera() {
        manager.openCamera(from: ["entity_id": "camera.front_door"])
        waitUntil("camera displayed") { CameraOverlayPresenter.shared.displayedCamera != nil }

        manager.hideCamera()

        waitUntil("camera hidden") { CameraOverlayPresenter.shared.displayedCamera == nil }
        XCTAssertFalse(Current.kiosk.isCameraOverlayVisible)
    }

    // MARK: - Helpers

    private func pumpMainQueue(for interval: TimeInterval = 0.2) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }

    private func waitUntil(_ what: String, timeout: TimeInterval = 5, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "timed out waiting for \(what)")
    }
}
