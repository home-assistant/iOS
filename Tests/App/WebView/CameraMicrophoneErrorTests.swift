@testable import HomeAssistant
import Shared
import XCTest

final class CameraMicrophoneErrorTests: XCTestCase {
    func testEveryErrorHasTheCodeTheFrontendMatchesOn() {
        XCTAssertEqual(CameraMicrophoneError.microphoneDenied.code, "microphone_denied")
        XCTAssertEqual(CameraMicrophoneError.serverUnavailable.code, "server_unavailable")
        XCTAssertEqual(CameraMicrophoneError.signalingFailed(nil).code, "signaling_failed")
        XCTAssertEqual(CameraMicrophoneError.connectionFailed.code, "connection_failed")
        XCTAssertEqual(CameraMicrophoneError.timedOut.code, "timeout")
        XCTAssertEqual(CameraMicrophoneError.interrupted.code, "interrupted")
    }

    func testEveryErrorHasAMessage() {
        let errors: [CameraMicrophoneError] = [
            .microphoneDenied,
            .serverUnavailable,
            .signalingFailed(nil),
            .connectionFailed,
            .timedOut,
            .interrupted,
        ]

        for error in errors {
            XCTAssertFalse(error.message.isEmpty, "\(error) has no message")
        }
    }

    func testASignalingFailureCarriesTheServersMessage() {
        XCTAssertEqual(CameraMicrophoneError.signalingFailed("Camera offline").message, "Camera offline")
    }

    func testASignalingFailureWithoutAServerMessageIsLocalized() {
        XCTAssertEqual(
            CameraMicrophoneError.signalingFailed(nil).message,
            L10n.CameraMicrophone.Errors.signalingFailed
        )
    }
}
