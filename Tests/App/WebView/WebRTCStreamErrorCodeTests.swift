@testable import HomeAssistant
import XCTest

final class WebRTCStreamErrorCodeTests: XCTestCase {
    func testRawValuesMatchTheCodesTheFrontendReceives() {
        XCTAssertEqual(WebRTCStreamErrorCode.unsupportedStreamType.rawValue, "unsupported_stream_type")
        XCTAssertEqual(WebRTCStreamErrorCode.invalidPayload.rawValue, "invalid_payload")
        XCTAssertEqual(WebRTCStreamErrorCode.microphoneDenied.rawValue, "microphone_denied")
        XCTAssertEqual(WebRTCStreamErrorCode.serverUnavailable.rawValue, "server_unavailable")
        XCTAssertEqual(WebRTCStreamErrorCode.signalingFailed.rawValue, "signaling_failed")
        XCTAssertEqual(WebRTCStreamErrorCode.connectionFailed.rawValue, "connection_failed")
        XCTAssertEqual(WebRTCStreamErrorCode.timedOut.rawValue, "timeout")
        XCTAssertEqual(WebRTCStreamErrorCode.interrupted.rawValue, "interrupted")

        XCTAssertEqual(WebRTCStreamErrorCode.allCases.count, 8)
    }
}
