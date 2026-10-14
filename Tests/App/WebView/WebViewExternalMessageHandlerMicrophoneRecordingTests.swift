@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import XCTest

final class WebViewExternalMessageHandlerMicrophoneRecordingTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var sessions: [FakeMicrophoneRecordingSession] = []

    override func setUp() async throws {
        sessions = []
        mockWebViewController = MockWebViewController()
        let bridge = MicrophoneRecordingBridge(notificationCenter: NotificationCenter()) { [weak self] in
            let session = FakeMicrophoneRecordingSession(sessionId: "session-\((self?.sessions.count ?? 0) + 1)")
            self?.sessions.append(session)
            return session
        }
        sut = WebViewExternalMessageHandler(improvManager: ImprovManager.shared, microphoneRecordingBridge: bridge)
        sut.webViewController = mockWebViewController
    }

    override func tearDown() async throws {
        sut = nil
        mockWebViewController = nil
        sessions = []
    }

    @MainActor func testStartAnswersWithTheSessionOnceRecording() throws {
        sut.handleExternalMessage(startMessage(id: 7))
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.startCount, 1)

        let reply = try messageSentToTheFrontend { session.record() }

        XCTAssertEqual(reply["id"] as? Int, 7)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, true)
        XCTAssertEqual(reply["result"] as? [String: String], ["session_id": "session-1"])
        XCTAssertNil(reply["error"])
    }

    @MainActor func testAFailedStartAnswersWithItsError() throws {
        sut.handleExternalMessage(startMessage(id: 8))
        let session = try XCTUnwrap(sessions.first)

        let reply = try messageSentToTheFrontend { session.fail(.microphoneDenied) }

        XCTAssertEqual(reply["id"] as? Int, 8)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual(reply["error"] as? [String: String], [
            "code": "microphone_denied",
            "message": MicrophoneRecordingError.microphoneDenied.message,
        ])
    }

    @MainActor func testStopAnswersWithTheRecording() throws {
        let session = try startRecording()
        sut.handleExternalMessage(stopMessage(id: 12, sessionId: "session-1"))
        XCTAssertEqual(session.finishCount, 1)

        let reply = try messageSentToTheFrontend {
            session.deliver(.success(MicrophoneRecording(
                sessionId: "session-1",
                audio: Data([1, 2, 3]),
                sampleRate: 16000,
                channels: 1,
                duration: 1.5
            )))
        }

        XCTAssertEqual(reply["id"] as? Int, 12)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, true)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["session_id"] as? String, "session-1")
        XCTAssertEqual(result["audio"] as? String, "AQID")
        XCTAssertEqual(result["mime_type"] as? String, "audio/wav")
        XCTAssertEqual(result["sample_rate"] as? Int, 16000)
        XCTAssertEqual(result["channels"] as? Int, 1)
        XCTAssertEqual(result["duration"] as? Double, 1.5)
    }

    @MainActor func testAStopThatCannotReadTheRecordingAnswersWithItsError() throws {
        let session = try startRecording()
        sut.handleExternalMessage(stopMessage(id: 12, sessionId: "session-1"))

        let reply = try messageSentToTheFrontend { session.deliver(.failure(.recordingFailed)) }

        XCTAssertEqual(reply["id"] as? Int, 12)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual((reply["error"] as? [String: String])?["code"], "recording_failed")
    }

    @MainActor func testStopForAnUnknownSessionIsNotFound() throws {
        let session = try startRecording()

        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(stopMessage(id: 12, sessionId: "session-2"))
        }

        XCTAssertEqual(session.finishCount, 0)
        XCTAssertEqual(reply["id"] as? Int, 12)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual(reply["error"] as? [String: String], [
            "code": "not_found",
            "message": MicrophoneRecordingError.sessionNotFound.message,
        ])
    }

    @MainActor func testStopWithoutASessionIsRejected() throws {
        let session = try startRecording()

        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 13, "type": "microphone/recording/stop"])
        }

        XCTAssertEqual(session.finishCount, 0)
        XCTAssertEqual(reply["id"] as? Int, 13)
        XCTAssertEqual(reply["success"] as? Bool, false)
        XCTAssertEqual(reply["error"] as? [String: String], [
            "code": "invalid_payload",
            "message": "session_id is required",
        ])
    }

    @MainActor func testARecordingTheAppEndsTellsTheFrontendWhyAndCanStillBeCollected() throws {
        let session = try startRecording()

        let command = try messageSentToTheFrontend { session.end(.interrupted) }

        XCTAssertEqual(command["type"] as? String, "command")
        XCTAssertEqual(command["command"] as? String, "microphone/recording/stopped")
        XCTAssertEqual(command["payload"] as? [String: String], ["session_id": "session-1", "reason": "interrupted"])

        sut.handleExternalMessage(stopMessage(id: 14, sessionId: "session-1"))
        XCTAssertEqual(session.finishCount, 1)
    }

    @MainActor func testANewFrontendPageDiscardsTheRecordingsOfThePreviousOne() throws {
        let session = try startRecording()

        _ = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        XCTAssertEqual(session.discardCount, 1)
    }

    @MainActor func testTheConfigurationAdvertisesMicrophoneRecording() throws {
        let reply = try messageSentToTheFrontend {
            sut.handleExternalMessage(["id": 1, "type": "config/get"])
        }

        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["hasMicrophoneRecording"] as? Bool, true)
    }

    // MARK: - Helpers

    @MainActor private func startRecording() throws -> FakeMicrophoneRecordingSession {
        sut.handleExternalMessage(startMessage(id: 7))
        let session = try XCTUnwrap(sessions.last)
        _ = try messageSentToTheFrontend { session.record() }
        return session
    }

    private func startMessage(id: Int) -> [String: Any] {
        ["id": id, "type": "microphone/recording/start"]
    }

    private func stopMessage(id: Int, sessionId: String) -> [String: Any] {
        ["id": id, "type": "microphone/recording/stop", "payload": ["session_id": sessionId]]
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
