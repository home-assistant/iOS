@testable import HomeAssistant
import XCTest

/// The playlist the HLS player hands to AVPlayer has to sit under the server's own URL, including
/// for a server installed on a subpath.
final class CameraStreamHLSViewTests: XCTestCase {
    func testTheServerAbsolutePlaylistPathIsJoinedWithoutADoubleSlash() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://homeassistant.local:8123"))

        let url = CameraStreamHLSView.playlistURL(
            baseURL: baseURL,
            hlsPath: "/api/hls/token/master_playlist.m3u8"
        )

        XCTAssertEqual(url.absoluteString, "https://homeassistant.local:8123/api/hls/token/master_playlist.m3u8")
    }

    /// A server reached through a subpath keeps it: dropping the base path would point the player
    /// at a playlist that isn't there.
    func testAServerOnASubpathKeepsItsBasePath() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.com/ha"))

        let url = CameraStreamHLSView.playlistURL(
            baseURL: baseURL,
            hlsPath: "/api/hls/token/master_playlist.m3u8"
        )

        XCTAssertEqual(url.absoluteString, "https://example.com/ha/api/hls/token/master_playlist.m3u8")
    }

    func testARelativePlaylistPathIsAppendedAsIs() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://homeassistant.local:8123"))

        let url = CameraStreamHLSView.playlistURL(baseURL: baseURL, hlsPath: "api/hls/token/index.m3u8")

        XCTAssertEqual(url.absoluteString, "https://homeassistant.local:8123/api/hls/token/index.m3u8")
    }
}
