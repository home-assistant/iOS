import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the client certificate screen reached from a server's settings, with and without a
/// certificate installed.
@Suite(.serialized)
@MainActor
struct ClientCertificateViewTests {
    private func server(certificate: ClientCertificate?) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: URL(string: "http://internal.example.com:8123"),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure,
                clientCertificate: certificate
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    private let layout: SwiftUISnapshotLayout = .fixed(width: 390, height: 600)

    @Test func notConfigured() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        assertLightDarkSnapshots(
            of: NavigationView {
                ClientCertificateView(viewModel: ConnectionSettingsViewModel(server: server(certificate: nil)))
            },
            drawHierarchyInKeyWindow: true,
            layout: layout
        )
    }

    @Test func configured() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let certificate = ClientCertificate(
            keychainIdentifier: "test-server",
            displayName: "home.p12",
            importedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        assertLightDarkSnapshots(
            of: NavigationView {
                ClientCertificateView(viewModel: ConnectionSettingsViewModel(server: server(certificate: certificate)))
            },
            drawHierarchyInKeyWindow: true,
            layout: layout
        )
    }
}
