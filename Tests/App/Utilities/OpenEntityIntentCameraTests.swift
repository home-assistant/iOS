@testable import HomeAssistant
@testable import Shared
import XCTest

/// Opening a camera from the Control Center controls, Spotlight or Siri plays it in the native camera
/// player; every other entity still opens its more-info dialog.
@MainActor
final class OpenEntityIntentCameraTests: XCTestCase {
    private var previousURLOpener: URLOpening!
    private var urlOpener: MockURLOpener!

    override func setUp() {
        super.setUp()
        previousURLOpener = URLOpener.shared
        urlOpener = MockURLOpener()
        URLOpener.shared = urlOpener
    }

    override func tearDown() {
        URLOpener.shared = previousURLOpener
        urlOpener = nil
        super.tearDown()
    }

    func testShowEntityDetailsOpensACameraInThePlayer() async throws {
        let intent = ShowEntityDetailsAppIntent()
        intent.target = entity("camera.porch")

        _ = try await intent.perform()

        XCTAssertEqual(
            urlOpener.openedURLs.map(\.url),
            [AppConstants.openCameraDeeplinkURL(entityId: "camera.porch", serverId: "server-1")]
        )
    }

    func testShowEntityDetailsOpensAnythingElseInMoreInfo() async throws {
        let intent = ShowEntityDetailsAppIntent()
        intent.target = entity("light.porch")

        _ = try await intent.perform()

        XCTAssertEqual(
            urlOpener.openedURLs.map(\.url),
            [AppConstants.openEntityDestinationURL(entityId: "light.porch", serverId: "server-1")]
        )
    }

    @available(iOS 17, *)
    func testTheOpenEntityControlOpensACameraInThePlayer() async throws {
        let opened = expectation(description: "URL opened")
        urlOpener.onOpen = { _ in opened.fulfill() }
        let intent = OpenEntityAppIntent()
        intent.entity = entity("camera.porch")

        _ = try await intent.perform()
        await fulfillment(of: [opened], timeout: 30)

        XCTAssertEqual(
            urlOpener.openedURLs.map(\.url),
            [AppConstants.openCameraDeeplinkURL(entityId: "camera.porch", serverId: "server-1")]
        )
    }

    private func entity(_ entityId: String) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: "server-1-\(entityId)",
            entityId: entityId,
            serverId: "server-1",
            serverName: "Home",
            areaName: nil,
            deviceName: nil,
            floorName: nil,
            displayString: "Porch",
            iconName: "mdi:cctv"
        )
    }
}
