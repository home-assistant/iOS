@testable import HomeAssistant
@testable import Shared
import XCTest

final class CameraCallRequestTests: XCTestCase {
    private var servers: FakeServerManager!

    override func setUp() {
        super.setUp()
        servers = FakeServerManager()
    }

    func testTheCallComesFromTheServerThatSentThePush() throws {
        servers.addFake()
        var info = ServerInfo.fake()
        info.connection.webhookID = "doorbell-server"
        let sender = servers.add(identifier: .init(rawValue: "sender"), serverInfo: info)

        let request = try XCTUnwrap(CameraCallRequest(
            payload: ["entity_id": "camera.front_door", "webhook_id": "doorbell-server"],
            servers: servers,
            entityName: { entityId, server in
                server.identifier == sender.identifier && entityId == "camera.front_door" ? "Front door" : nil
            }
        ))

        XCTAssertEqual(request.cameraEntityId, "camera.front_door")
        XCTAssertEqual(request.cameraName, "Front door")
        XCTAssertEqual(request.server.identifier, sender.identifier)
    }

    func testTheCameraIsNamedByItsEntityWhenItIsNotKnown() throws {
        servers.addFake()

        let request = try XCTUnwrap(CameraCallRequest(
            payload: ["entity_id": "camera.front_door"],
            servers: servers,
            entityName: { _, _ in nil }
        ))

        XCTAssertEqual(request.cameraName, "camera.front_door")
    }

    func testASingleServerAnswersAPushFromAnUnknownWebhook() throws {
        let only = servers.addFake()

        let request = try XCTUnwrap(CameraCallRequest(
            payload: ["entity_id": "camera.front_door", "webhook_id": "unknown"],
            servers: servers,
            entityName: { _, _ in nil }
        ))

        XCTAssertEqual(request.server.identifier, only.identifier)
    }

    func testAnUnknownWebhookIsAmbiguousWithSeveralServers() {
        servers.addFake()
        servers.add(identifier: .init(rawValue: "second"), serverInfo: .fake())

        XCTAssertNil(CameraCallRequest(
            payload: ["entity_id": "camera.front_door", "webhook_id": "unknown"],
            servers: servers,
            entityName: { _, _ in nil }
        ))
    }

    func testOnlyCamerasCanCall() {
        servers.addFake()

        XCTAssertNil(CameraCallRequest(payload: ["entity_id": "light.kitchen"], servers: servers))
        XCTAssertNil(CameraCallRequest(payload: [:], servers: servers))
    }

    func testThereIsNoCallWithoutAServer() {
        XCTAssertNil(CameraCallRequest(payload: ["entity_id": "camera.front_door"], servers: servers))
    }
}
