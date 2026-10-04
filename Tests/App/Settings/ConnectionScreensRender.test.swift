import CoreLocation
import Foundation
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Stands in for `Current.locationManager` so the screens don't depend on what the simulator granted.
private final class ConnectionURLViewFakeLocationManager: LocationManagerProtocol {
    private let permissionState: LocationPermissionState
    private let accuracy: CLAccuracyAuthorization

    init(permissionState: LocationPermissionState, accuracy: CLAccuracyAuthorization) {
        self.permissionState = permissionState
        self.accuracy = accuracy
    }

    var currentPermissionState: LocationPermissionState { permissionState }
    var accuracyAuthorization: CLAccuracyAuthorization { accuracy }
    var isLocationServicesEnabled: Bool { true }
    func requestLocationPermission() {}
    func requestTemporaryFullAccuracyAuthorization(purposeKey: String, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

/// Lays the connection screens out so SwiftUI evaluates their bodies: each URL editor variant, the
/// webhook details and the per-server screen with a client certificate configured.
@MainActor
final class ConnectionScreensRenderTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousLocationManager: LocationManagerProtocol!
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var previousLastKnownNetworkState: (() -> NetworkState)!
    private var previousRefreshNetworkInformation: (() async -> Void)!
    private var servers: FakeServerManager!

    override func setUp() async throws {
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        previousLocationManager = Current.locationManager
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
        previousLastKnownNetworkState = Current.connectivity.lastKnownNetworkState
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation

        servers = FakeServerManager()
        Current.servers = servers
        Current.locationManager = ConnectionURLViewFakeLocationManager(
            permissionState: .authorizedWhenInUse,
            accuracy: .reducedAccuracy
        )
        let networkState = NetworkState(ssid: "MyWifi")
        Current.connectivity.currentNetworkState = { networkState }
        Current.connectivity.lastKnownNetworkState = { networkState }
        Current.connectivity.refreshNetworkInformation = {}
    }

    override func tearDown() async throws {
        Current.servers = previousServers
        Current.cachedApis = previousCachedApis
        Current.locationManager = previousLocationManager
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        Current.connectivity.lastKnownNetworkState = previousLastKnownNetworkState
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        servers = nil
    }

    /// Adds a server whose API talks to a mock connection, so nothing reaches the network.
    private func makeServer(
        internalURL: URL? = URL(string: "http://internal.example.com:8123"),
        externalURL: URL? = URL(string: "http://external.example.com"),
        remoteUIURL: URL? = nil,
        cloudhookURL: URL? = nil,
        useCloud: Bool = false,
        clientCertificate: ClientCertificate? = nil
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL,
                internalURL: internalURL,
                cloudhookURL: cloudhookURL,
                remoteUIURL: remoteUIURL,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: true,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        info.connection.clientCertificate = clientCertificate
        let server = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: info)

        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: server.identifier)
        return server
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View, height: CGFloat = 2000) async {
        let controller = UIHostingController(rootView: view.injectingViewControllerProvider())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        // `onAppear`/`task` work and the state it publishes land after the first pass.
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testRendersTheInternalURLEditor() async {
        let server = makeServer()
        await render(NavigationView { ConnectionURLView(server: server, urlType: .internal) })
    }

    func testRendersTheInternalURLEditorWithEveryPermissionGranted() async {
        Current.locationManager = ConnectionURLViewFakeLocationManager(
            permissionState: .authorizedAlways,
            accuracy: .fullAccuracy
        )
        let server = makeServer()
        await render(NavigationView { ConnectionURLView(server: server, urlType: .internal) })
    }

    /// A plain-HTTP external URL shows the security warning under the field.
    func testRendersTheExternalURLEditorWithAnInsecureURL() async {
        let server = makeServer(externalURL: URL(string: "http://external.example.com"))
        await render(NavigationView { ConnectionURLView(server: server, urlType: .external) })
    }

    /// With Home Assistant Cloud on, the external URL field gives way to a note.
    func testRendersTheExternalURLEditorOverriddenByTheCloud() async {
        let server = makeServer(
            externalURL: nil,
            remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
            useCloud: true
        )
        await render(NavigationView { ConnectionURLView(server: server, urlType: .external) })
    }

    func testRendersTheWebhookDetails() async {
        let server = makeServer(
            externalURL: URL(string: "https://external.example.com"),
            remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
            cloudhookURL: URL(string: "https://hooks.nabu.casa/cloudhook-id")
        )
        await render(NavigationView { WebhookDetailView(server: server) })
    }

    func testRendersTheWebhookDetailsWithoutACloudhook() async {
        let server = makeServer(internalURL: nil)
        await render(NavigationView { WebhookDetailView(server: server) })
    }

    func testRendersTheServerScreenWithAValidCertificateAndSeveralServers() async {
        let certificate = ClientCertificate(
            keychainIdentifier: "identity",
            displayName: "My Certificate",
            expiresAt: Date().addingTimeInterval(365 * 24 * 60 * 60)
        )
        let server = makeServer(clientCertificate: certificate)
        _ = makeServer()

        await render(NavigationView { ConnectionSettingsView(server: server) }, height: 2600)
    }

    func testRendersTheServerScreenWithAnExpiredCertificate() async {
        let certificate = ClientCertificate(
            keychainIdentifier: "identity",
            displayName: "Old Certificate",
            expiresAt: Date().addingTimeInterval(-24 * 60 * 60)
        )
        XCTAssertTrue(certificate.isExpired)
        let server = makeServer(clientCertificate: certificate)

        await render(NavigationView { ConnectionSettingsView(server: server) }, height: 2600)
    }
}
