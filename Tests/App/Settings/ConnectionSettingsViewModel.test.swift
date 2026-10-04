import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The per-server connection screen mirrors the server's info into editable fields and writes each
/// edit straight back to the server.
@MainActor
final class ConnectionSettingsViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var servers: FakeServerManager!

    override func setUp() async throws {
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        servers = FakeServerManager()
        Current.servers = servers
    }

    override func tearDown() async throws {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        servers = nil
    }

    /// Adds a server whose API talks to a mock connection, so nothing reaches the network.
    private func makeServer(
        identifier: String = UUID().uuidString,
        internalURL: URL? = URL(string: "http://internal.example.com:8123"),
        externalURL: URL? = URL(string: "https://external.example.com"),
        remoteUIURL: URL? = nil,
        useCloud: Bool = false,
        clientCertificate: ClientCertificate? = nil,
        version: Version = "2024.1"
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL,
                internalURL: internalURL,
                cloudhookURL: nil,
                remoteUIURL: remoteUIURL,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: version
        )
        info.connection.useCloud = useCloud
        info.connection.clientCertificate = clientCertificate
        let server = servers.add(identifier: .init(rawValue: identifier), serverInfo: info)

        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: server.identifier)
        return server
    }

    func testMirrorsTheServerInfo() {
        let server = makeServer()

        let viewModel = ConnectionSettingsViewModel(server: server)

        XCTAssertEqual(viewModel.serverName, "Test Server")
        XCTAssertEqual(viewModel.version, server.info.version.description)
        XCTAssertEqual(viewModel.connectionPath, server.info.connection.activeURLType.description)
        XCTAssertEqual(viewModel.internalURL, "http://internal.example.com:8123")
        XCTAssertEqual(viewModel.externalURL, "https://external.example.com")
        XCTAssertEqual(viewModel.securityLevel, .mostSecure)
        XCTAssertEqual(viewModel.locationName, "")
        XCTAssertEqual(viewModel.deviceName, "")
        XCTAssertNil(viewModel.clientCertificate)
        XCTAssertFalse(viewModel.localPushStatus.isEmpty)
        XCTAssertFalse(viewModel.hasMultipleServers)
        XCTAssertFalse(viewModel.versionRequiresLocationGPSOptional)
    }

    func testMissingURLsShowADash() {
        let server = makeServer(internalURL: nil, externalURL: URL(string: "https://external.example.com"))

        let viewModel = ConnectionSettingsViewModel(server: server)

        XCTAssertEqual(viewModel.internalURL, "—")
        XCTAssertFalse(viewModel.shouldShowSecurityLevelPicker)
    }

    func testHomeAssistantCloudReplacesTheExternalURL() {
        let server = makeServer(
            externalURL: nil,
            remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
            useCloud: true
        )

        let viewModel = ConnectionSettingsViewModel(server: server)

        XCTAssertEqual(viewModel.externalURL, L10n.Settings.ConnectionSection.HomeAssistantCloud.title)
        XCTAssertTrue(viewModel.canShareServer)
    }

    func testSecurityLevelPickerOnlyForAPlainHTTPInternalURL() {
        let httpServer = makeServer(internalURL: URL(string: "http://internal.example.com:8123"))
        XCTAssertTrue(ConnectionSettingsViewModel(server: httpServer).shouldShowSecurityLevelPicker)

        let httpsServer = makeServer(internalURL: URL(string: "https://internal.example.com:8123"))
        XCTAssertFalse(ConnectionSettingsViewModel(server: httpsServer).shouldShowSecurityLevelPicker)
    }

    func testOldCoreVersionsRequireLocationGPS() {
        let server = makeServer(version: .init(major: 2021, minor: 1, patch: 0, prerelease: nil, build: nil))

        XCTAssertTrue(ConnectionSettingsViewModel(server: server).versionRequiresLocationGPSOptional)
    }

    func testHasMultipleServersWithASecondServer() {
        let server = makeServer()
        _ = makeServer()

        XCTAssertTrue(ConnectionSettingsViewModel(server: server).hasMultipleServers)
    }

    func testSharingNeedsAnInvitationURL() {
        let shareable = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: shareable)
        XCTAssertTrue(viewModel.canShareServer)
        XCTAssertNotNil(viewModel.shareServer())

        let unreachable = makeServer(internalURL: nil, externalURL: nil)
        let unreachableViewModel = ConnectionSettingsViewModel(server: unreachable)
        XCTAssertFalse(unreachableViewModel.canShareServer)
        XCTAssertNil(unreachableViewModel.shareServer())
    }

    func testUpdatingTheLocationNameWritesThroughToTheServer() {
        let server = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: server)

        viewModel.updateLocationName("Cottage")
        XCTAssertEqual(viewModel.locationName, "Cottage")
        XCTAssertEqual(server.info.setting(for: .localName), "Cottage")

        viewModel.updateLocationName(nil)
        XCTAssertEqual(viewModel.locationName, "")
        XCTAssertNil(server.info.setting(for: .localName))
    }

    func testUpdatingTheDeviceNameWritesThroughToTheServer() {
        let server = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: server)

        viewModel.updateDeviceName("Kitchen iPad")
        XCTAssertEqual(viewModel.deviceName, "Kitchen iPad")
        XCTAssertEqual(server.info.setting(for: .overrideDeviceName), "Kitchen iPad")

        viewModel.updateDeviceName(nil)
        XCTAssertEqual(viewModel.deviceName, "")
        XCTAssertNil(server.info.setting(for: .overrideDeviceName))
    }

    func testUpdatingTheSecurityLevelWritesThroughToTheServer() {
        let server = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: server)

        viewModel.updateSecurityLevel(.lessSecure)

        XCTAssertEqual(viewModel.securityLevel, .lessSecure)
        XCTAssertEqual(server.info.connection.connectionAccessSecurityLevel, .lessSecure)
    }

    func testRemovingWithoutACertificateDoesNothing() {
        let server = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: server)

        viewModel.removeCertificate()

        XCTAssertNil(viewModel.clientCertificate)
        XCTAssertNil(server.info.connection.clientCertificate)
    }

    /// Another server still uses the same Keychain identity, so only this server lets go of it.
    func testRemovingASharedCertificateDetachesItFromThisServerOnly() {
        let certificate = ClientCertificate(keychainIdentifier: "shared-identity", displayName: "Shared")
        let server = makeServer(clientCertificate: certificate)
        let otherServer = makeServer(clientCertificate: certificate)
        let viewModel = ConnectionSettingsViewModel(server: server)
        XCTAssertEqual(viewModel.clientCertificate?.keychainIdentifier, "shared-identity")

        viewModel.removeCertificate()

        XCTAssertNil(viewModel.clientCertificate)
        XCTAssertNil(server.info.connection.clientCertificate)
        XCTAssertEqual(otherServer.info.connection.clientCertificate?.keychainIdentifier, "shared-identity")
    }

    func testImportingAMissingFileReportsAnError() async {
        let server = makeServer()
        let viewModel = ConnectionSettingsViewModel(server: server)
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).p12")

        await viewModel.importCertificate(from: missingFile, password: "secret")

        XCTAssertNotNil(viewModel.certificateError)
        XCTAssertFalse(viewModel.isImportingCertificate)
        XCTAssertNil(viewModel.clientCertificate)
        XCTAssertNil(server.info.connection.clientCertificate)
    }
}
