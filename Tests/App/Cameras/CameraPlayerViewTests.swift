@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class CameraPlayerViewTests: XCTestCase {
    func testSwitchingCameraReportsTheNewCameraOnce() {
        var reported: [String] = []
        let view = CameraPlayerView(
            server: ServerFixture.standard,
            cameraEntityId: "camera.front_door",
            onCameraChange: { reported.append($0) }
        )

        // Picking the camera already showing is a no-op; picking another one reports it.
        view.switchCamera(to: "camera.front_door")
        XCTAssertEqual(reported, [])

        view.switchCamera(to: "camera.backyard")
        XCTAssertEqual(reported, ["camera.backyard"])
    }
}
