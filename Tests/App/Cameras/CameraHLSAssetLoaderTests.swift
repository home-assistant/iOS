@testable import HomeAssistant
@testable import Shared
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

    /// Nothing to take over means no delegate to keep alive either — the caller gets a plain asset
    /// and AVFoundation does its own networking, as it always has.
    func testAPlainServerIsGivenAnAssetWithNoLoaderToHold() throws {
        let (api, cleanUp) = makeAPI()
        defer { cleanUp() }
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/api/hls/index.m3u8"))

        let (asset, loader) = CameraHLSAssetLoader.asset(for: url, api: api)

        XCTAssertEqual(asset.url, url)
        XCTAssertNil(loader)
    }

    /// With a client certificate the asset is built for custom loading and the loader has to come
    /// back with it: the asset does not retain its delegate, so dropping it here would stop the
    /// stream mid-load.
    func testAServerWithAClientCertificateIsGivenALoaderToHold() throws {
        let (api, cleanUp) = makeAPI { connection in
            connection.clientCertificate = ClientCertificate(
                keychainIdentifier: "identifier",
                displayName: "A Certificate"
            )
        }
        defer { cleanUp() }
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/api/hls/index.m3u8"))

        let (asset, loader) = CameraHLSAssetLoader.asset(for: url, api: api)

        XCTAssertEqual(asset.url, url)
        XCTAssertNotNil(loader)
    }

    /// Builds an API against a throwaway server, optionally with its connection adjusted, and hands
    /// back the teardown that puts the environment's servers back.
    private func makeAPI(
        configure: ((inout ConnectionInfo) -> Void)? = nil
    ) -> (api: HomeAssistantAPI, cleanUp: () -> Void) {
        let previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        let server = servers.addFake()
        if let configure {
            configure(&server.info.connection)
        }
        return (HomeAssistantAPI(server: server), { Current.servers = previousServers })
    }
}
