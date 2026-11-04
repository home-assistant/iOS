@testable import HomeAssistant
import Shared
import XCTest

final class CameraMicrophoneErrorTests: XCTestCase {
    func testEveryErrorHasTheCodeTheFrontendMatchesOn() {
        XCTAssertEqual(CameraMicrophoneError.microphoneDenied.code, .microphoneDenied)
        XCTAssertEqual(CameraMicrophoneError.serverUnavailable.code, .serverUnavailable)
        XCTAssertEqual(CameraMicrophoneError.signalingFailed(nil).code, .signalingFailed)
        XCTAssertEqual(CameraMicrophoneError.signalingFailed("Camera offline").code, .signalingFailed)
        XCTAssertEqual(CameraMicrophoneError.connectionFailed.code, .connectionFailed)
        XCTAssertEqual(CameraMicrophoneError.timedOut.code, .timedOut)
        XCTAssertEqual(CameraMicrophoneError.interrupted.code, .interrupted)
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
