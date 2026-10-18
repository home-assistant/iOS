@testable import HomeAssistant
import XCTest

/// The cascade the camera player runs: which method is on screen, when the loader covers it, and
/// what a failure moves on to.
final class CameraPlayerPlaybackTests: XCTestCase {
    func testThereIsNoMethodUntilAPlanArrives() {
        let playback = CameraPlayerPlayback()

        XCTAssertNil(playback.current)
        XCTAssertTrue(playback.isLoaderVisible(webRTCIsLoading: false))
    }

    func testStartingAPlanShowsItsMostPreferredMethod() {
        var playback = CameraPlayerPlayback()

        playback.start(with: [.webRTC, .hls, .mjpeg])

        XCTAssertEqual(playback.current, .webRTC)
        XCTAssertEqual(playback.index, 0)
    }

    func testAFailureMovesToTheNextMethod() {
        var playback = CameraPlayerPlayback()
        playback.start(with: [.webRTC, .hls, .mjpeg])

        XCTAssertEqual(playback.advance(from: .webRTC), .hls)
        XCTAssertEqual(playback.current, .hls)
        XCTAssertEqual(playback.advance(from: .hls), .mjpeg)
        XCTAssertEqual(playback.current, .mjpeg)
    }

    /// WebRTC reports an unsupported camera and a failed connection separately, so the second
    /// report must not skip HLS on its way past a method that has already been replaced.
    func testAFailureFromAMethodAlreadyReplacedChangesNothing() {
        var playback = CameraPlayerPlayback()
        playback.start(with: [.webRTC, .hls, .mjpeg])
        playback.advance(from: .webRTC)

        XCTAssertNil(playback.advance(from: .webRTC))
        XCTAssertEqual(playback.current, .hls)
    }

    func testTheLastMethodHasNothingToFallBackTo() {
        var playback = CameraPlayerPlayback()
        playback.start(with: [.hls, .mjpeg])
        playback.advance(from: .hls)

        XCTAssertNil(playback.advance(from: .mjpeg))
        XCTAssertEqual(playback.current, .mjpeg)
    }

    /// The WebRTC player reports its loading state upwards; the others draw their own spinner, so
    /// showing this one over them would leave a spinner nothing ever clears.
    func testOnlyWebRTCDrivesTheSharedLoader() {
        var playback = CameraPlayerPlayback()
        playback.start(with: [.webRTC, .hls, .mjpeg])

        XCTAssertTrue(playback.isLoaderVisible(webRTCIsLoading: true))
        XCTAssertFalse(playback.isLoaderVisible(webRTCIsLoading: false))

        playback.advance(from: .webRTC)
        XCTAssertFalse(playback.isLoaderVisible(webRTCIsLoading: true))
    }

    /// Switching camera drops the plan, so the loader covers the screen until the new camera's
    /// capabilities decide what to play.
    func testClearingSendsTheLoaderBack() {
        var playback = CameraPlayerPlayback()
        playback.start(with: [.webRTC, .mjpeg])
        playback.advance(from: .webRTC)

        playback.clear()

        XCTAssertNil(playback.current)
        XCTAssertEqual(playback.index, 0)
        XCTAssertTrue(playback.isLoaderVisible(webRTCIsLoading: false))
    }
}
