import Foundation
import ObjectMapper
@testable import Shared
import XCTest

final class StreamCameraResponseTests: XCTestCase {
    func testMapsHLSAndMJPEGPaths() throws {
        let response = try XCTUnwrap(StreamCameraResponse(JSON: [
            "hls_path": "/api/hls/abc/master_playlist.m3u8",
            "mjpeg_path": "/api/camera_proxy_stream/camera.front",
        ]))

        XCTAssertEqual(response.hlsPath, "/api/hls/abc/master_playlist.m3u8")
        XCTAssertEqual(response.mjpegPath, "/api/camera_proxy_stream/camera.front")
    }

    func testMapsOnlyHLSPath() throws {
        let response = try XCTUnwrap(StreamCameraResponse(JSON: ["hls_path": "/api/hls/abc"]))

        XCTAssertEqual(response.hlsPath, "/api/hls/abc")
        XCTAssertNil(response.mjpegPath)
    }

    func testMapsOnlyMJPEGPath() throws {
        let response = try XCTUnwrap(StreamCameraResponse(JSON: ["mjpeg_path": "/api/mjpeg"]))

        XCTAssertNil(response.hlsPath)
        XCTAssertEqual(response.mjpegPath, "/api/mjpeg")
    }

    func testResponseWithoutAnyPathIsRejected() {
        XCTAssertNil(StreamCameraResponse(JSON: ["message": "Camera is not available"]))
        XCTAssertNil(StreamCameraResponse(JSON: [:]))
    }

    func testFallbackUsesCameraProxyStream() {
        let response = StreamCameraResponse(fallbackEntityID: "camera.driveway")

        XCTAssertNil(response.hlsPath)
        XCTAssertEqual(response.mjpegPath, "/api/camera_proxy_stream/camera.driveway")
    }
}
