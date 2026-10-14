@testable import HomeAssistant
@testable import Shared
import XCTest

final class MicrophoneRecordingErrorTests: XCTestCase {
    func testEachErrorHasTheCodeTheFrontendMatchesOn() {
        XCTAssertEqual(MicrophoneRecordingError.microphoneDenied.code, "microphone_denied")
        XCTAssertEqual(MicrophoneRecordingError.recordingFailed.code, "recording_failed")
        XCTAssertEqual(MicrophoneRecordingError.sessionNotFound.code, "not_found")
        XCTAssertEqual(MicrophoneRecordingError.interrupted.code, "interrupted")
    }

    func testEachErrorHasALocalizedMessage() {
        XCTAssertEqual(
            MicrophoneRecordingError.microphoneDenied.message,
            L10n.MicrophoneRecording.Errors.microphoneDenied
        )
        XCTAssertEqual(
            MicrophoneRecordingError.recordingFailed.message,
            L10n.MicrophoneRecording.Errors.recordingFailed
        )
        XCTAssertEqual(
            MicrophoneRecordingError.sessionNotFound.message,
            L10n.MicrophoneRecording.Errors.sessionNotFound
        )
        XCTAssertEqual(MicrophoneRecordingError.interrupted.message, L10n.MicrophoneRecording.Errors.interrupted)
    }
}
