@testable import HomeAssistant
import XCTest

/// The player picks its streaming method from what the camera says it supports, the way
/// `ha-camera-stream` does, instead of opening with WebRTC on every camera and finding out by
/// failing.
final class CameraStreamPlanTests: XCTestCase {
    /// A camera with no stream support at all — no `CameraEntityFeature.STREAM` — is exactly the
    /// case the frontend shows the MJPEG proxy for.
    func testACameraThatSupportsNoStreamTypeGoesStraightToMJPEG() {
        let players = CameraStreamPlan.players(for: CameraCapabilities(frontendStreamTypes: []))
        XCTAssertEqual(players, [.mjpeg])
    }

    /// The common `stream`-component camera with no WebRTC provider behind it. Opening with WebRTC
    /// here only earns a rejection from core.
    func testAnHLSOnlyCameraNeverTriesWebRTC() {
        let players = CameraStreamPlan.players(for: CameraCapabilities(frontendStreamTypes: [.hls]))
        XCTAssertEqual(players, [.hls, .mjpeg])
    }

    /// A camera with a native WebRTC implementation, such as Nest, has no HLS stream to fall back
    /// to, so the fallback after WebRTC is the still-image proxy.
    func testAWebRTCOnlyCameraFallsBackToMJPEG() {
        let players = CameraStreamPlan.players(for: CameraCapabilities(frontendStreamTypes: [.webRTC]))
        XCTAssertEqual(players, [.webRTC, .mjpeg])
    }

    /// The go2rtc case: WebRTC is preferred, and HLS is a real fallback rather than a dead end.
    func testACameraThatSupportsBothPrefersWebRTCAndKeepsHLS() {
        let players = CameraStreamPlan.players(for: CameraCapabilities(frontendStreamTypes: [.hls, .webRTC]))
        XCTAssertEqual(players, [.webRTC, .hls, .mjpeg])
    }

    /// When the server can't say — an older core, or a request that failed — the player keeps the
    /// try-everything behaviour rather than refusing to play.
    func testUnknownCapabilitiesTryEveryStreamingMethod() {
        XCTAssertEqual(CameraStreamPlan.players(for: nil), [.webRTC, .hls, .mjpeg])
    }
}
