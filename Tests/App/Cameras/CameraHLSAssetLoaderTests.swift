@testable import HomeAssistant
import Shared
import XCTest

/// AVFoundation can neither present a client certificate nor answer the trust challenge a security
/// exception covers, so the player has to know when to fetch the stream itself instead.
final class CameraHLSAssetLoaderTests: XCTestCase {
    private var connection: ConnectionInfo!

    override func setUp() {
        super.setUp()
        ServerFixture.reset()
        connection = ServerFixture.standard.info.connection
    }

    override func tearDown() {
        connection = nil
        ServerFixture.reset()
        super.tearDown()
    }

    func testAPlainServerLetsAVFoundationDoItsOwnLoading() throws {
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/api/hls/index.m3u8"))

        XCTAssertFalse(CameraHLSAssetLoader.needsCustomLoading(url: url, connection: connection))
    }

    func testAServerWithAClientCertificateNeedsItsRequestsRoutedThroughTheApp() throws {
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/api/hls/index.m3u8"))
        connection.clientCertificate = ClientCertificate(
            keychainIdentifier: "identifier",
            displayName: "A Certificate"
        )

        XCTAssertTrue(CameraHLSAssetLoader.needsCustomLoading(url: url, connection: connection))
    }

    /// A local file never goes near the server's TLS, so taking its loading over would only add a
    /// hop that can fail.
    func testALocalFileIsLoadedDirectlyEvenWithAClientCertificate() throws {
        let url = URL(fileURLWithPath: "/tmp/index.m3u8")
        connection.clientCertificate = ClientCertificate(
            keychainIdentifier: "identifier",
            displayName: "A Certificate"
        )

        XCTAssertFalse(CameraHLSAssetLoader.needsCustomLoading(url: url, connection: connection))
    }
}
