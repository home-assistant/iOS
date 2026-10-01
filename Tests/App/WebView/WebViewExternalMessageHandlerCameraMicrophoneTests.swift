@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import XCTest

final class WebViewExternalMessageHandlerCameraMicrophoneTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var sessions: [FakeCameraMicrophoneSession] = []

    override func setUp() async throws {
        sessions = []
        mockWebViewController = MockWebViewController()
        let bridge = CameraMicrophoneBridge(notificationCenter: NotificationCenter()) { [weak self] server, entityId in
            let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: entityId)
            self?.sessions.append(session)
            return session
        }
        sut = WebViewExternalMessageHandler(improvManager: ImprovManager.shared, cameraMicrophoneBridge: bridge)
        sut.webViewController = mockWebViewController
    }

    override func tearDown() async throws {
        sut = nil
        mockWebViewController = nil
        sessions = []
    }

    @MainActor func testStartOpensAMicrophoneSessionForTheCameraOnTheWebViewsServer() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cameraEntityId, "camera.front_door")
        XCTAssertEqual(session.server.identifier, mockWebViewController.server.identifier)
        XCTAssertEqual(session.startCount, 1)
    }

    @MainActor func testAConnectedSessionAnswersTheStartWithSuccess() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)

        let reply = try messageSentToTheFrontend { session.connect() }

        XCTAssertEqual(reply["id"] as? Int, 7)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, true)
        XCTAssertNil(reply["error"])
    }

    @MainActor func testAFailedSessionAnswersTheStartWithItsError() throws {
        sut.handleExternalMessage(startMessage(id: 8, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)

        let reply = try messageSentToTheFrontend { session.fail(.microphoneDenied) }

        XCTAssertEqual(reply["id"] as? Int, 8)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual(reply["error"] as? [String: String], [
            "code": "microphone_denied",
            "message": CameraMicrophoneError.microphoneDenied.message,
        ])
    }

    @MainActor func testAStartWithoutACameraIsRejected() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 9, "type": "camera/microphone/start"])
        }

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(reply["id"] as? Int, 9)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual((reply["error"] as? [String: String])?["code"], "invalid_payload")
    }

    @MainActor func testStopEndsTheSessionOfTheCamera() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)

        sut.handleExternalMessage(stopMessage(entityId: "camera.garden"))
        XCTAssertEqual(session.stopCount, 0)

        sut.handleExternalMessage(stopMessage(entityId: "camera.front_door"))
        XCTAssertEqual(session.stopCount, 1)
    }

    @MainActor func testStopWithoutACameraEndsTheActiveSession() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))

        sut.handleExternalMessage(["id": 10, "type": "camera/microphone/stop"])

        XCTAssertEqual(try XCTUnwrap(sessions.first).stopCount, 1)
    }

    @MainActor func testANewFrontendPageStopsTheMicrophoneOfThePreviousOne() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect() }

        _ = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        XCTAssertEqual(session.stopCount, 1)
    }

    @MainActor func testASessionEndingOnItsOwnTellsTheFrontend() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect() }

        let command = try messageSentToTheFrontend { session.end(.connectionFailed) }

        XCTAssertEqual(command["type"] as? String, "command")
        XCTAssertEqual(command["command"] as? String, "camera/microphone/stopped")
        XCTAssertEqual(command["payload"] as? [String: String], [
            "entity_id": "camera.front_door",
            "reason": "connection_failed",
        ])
    }

    @MainActor func testTheConfigurationAdvertisesTheCameraMicrophone() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["hasCameraMicrophone"] as? Bool, !Current.isCatalyst)
    }

    // MARK: - Helpers

    private func startMessage(id: Int, entityId: String) -> [String: Any] {
        ["id": id, "type": "camera/microphone/start", "payload": ["entity_id": entityId]]
    }

    private func stopMessage(entityId: String) -> [String: Any] {
        ["id": 11, "type": "camera/microphone/stop", "payload": ["entity_id": entityId]]
    }

    @MainActor private func messageSentToTheFrontend(
        after action: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let sent = expectation(description: "message sent to the frontend")
        mockWebViewController.evaluateJavaScriptExpectation = sent
        try action()
        wait(for: [sent], timeout: 5)
        mockWebViewController.evaluateJavaScriptExpectation = nil

        let script = try XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript, file: file, line: line)
        let prefix = "window.externalBus("
        XCTAssertTrue(script.hasPrefix(prefix), file: file, line: line)
        let json = Data(script.dropFirst(prefix.count).dropLast().utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any], file: file, line: line)
    }
}
