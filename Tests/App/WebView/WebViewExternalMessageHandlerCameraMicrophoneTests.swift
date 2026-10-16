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

    @MainActor func testAConnectedSessionAnswersTheStartWithItsSession() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)

        let reply = try messageSentToTheFrontend { session.connect(sessionId: "session-1") }

        XCTAssertEqual(reply["id"] as? Int, 7)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, true)
        XCTAssertEqual(reply["result"] as? [String: String], ["session_id": "session-1"])
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
            sut.handleExternalMessage([
                "id": 9,
                "type": "webrtc/stream/start",
                "payload": ["stream_type": "microphone"],
            ])
        }

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(reply["id"] as? Int, 9)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual((reply["error"] as? [String: String])?["code"], "invalid_payload")
    }

    @MainActor func testAStartForAnUnsupportedStreamTypeIsRejected() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(startMessage(id: 9, entityId: "camera.front_door", streamType: "video"))
        }

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(reply["id"] as? Int, 9)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual(reply["error"] as? [String: String], [
            "code": "unsupported_stream_type",
            "message": "Unsupported stream_type: video",
        ])
    }

    @MainActor func testAStartWithoutAStreamTypeIsRejected() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage([
                "id": 9,
                "type": "webrtc/stream/start",
                "payload": ["entity_id": "camera.front_door"],
            ])
        }

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual((reply["error"] as? [String: String])?["code"], "unsupported_stream_type")
    }

    @MainActor func testStopEndsTheSessionItNames() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect(sessionId: "session-1") }

        sut.handleExternalMessage(stopMessage(sessionId: "session-2"))
        XCTAssertEqual(session.stopCount, 0)

        sut.handleExternalMessage(stopMessage(sessionId: "session-1"))
        XCTAssertEqual(session.stopCount, 1)
    }

    @MainActor func testStopWithoutASessionIsIgnored() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect(sessionId: "session-1") }

        sut.handleExternalMessage(["id": 10, "type": "webrtc/stream/stop"])

        XCTAssertEqual(session.stopCount, 0)
    }

    @MainActor func testANewFrontendPageStopsTheMicrophoneOfThePreviousOne() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect(sessionId: "session-1") }

        _ = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        XCTAssertEqual(session.stopCount, 1)
    }

    @MainActor func testASessionEndingOnItsOwnTellsTheFrontend() throws {
        sut.handleExternalMessage(startMessage(id: 7, entityId: "camera.front_door"))
        let session = try XCTUnwrap(sessions.first)
        _ = try messageSentToTheFrontend { session.connect(sessionId: "session-1") }

        let command = try messageSentToTheFrontend { session.end(.connectionFailed) }

        XCTAssertEqual(command["type"] as? String, "command")
        XCTAssertEqual(command["command"] as? String, "webrtc/stream/stopped")
        XCTAssertEqual(command["payload"] as? [String: String], ["session_id": "session-1"])
    }

    @MainActor func testTheConfigurationAdvertisesTheCameraMicrophoneStream() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["hasCameraMicrophoneStream"] as? Bool, !Current.isCatalyst)
    }

    // MARK: - Helpers

    private func startMessage(id: Int, entityId: String, streamType: String = "microphone") -> [String: Any] {
        [
            "id": id,
            "type": "webrtc/stream/start",
            "payload": ["stream_type": streamType, "entity_id": entityId],
        ]
    }

    private func stopMessage(sessionId: String) -> [String: Any] {
        ["id": 11, "type": "webrtc/stream/stop", "payload": ["session_id": sessionId]]
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
