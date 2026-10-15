import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the router addresses sub-screen reached from the internal URL editor.
@Suite(.serialized)
@MainActor
struct ConnectionHardwareAddressesViewTests {
    @Test func addresses() async throws {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: nil,
                internalURL: URL(string: "http://internal.example.com:8123"),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: ["aa:bb:cc:dd:ee:ff", "11:22:33:44:55:66"],
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        let server = Server.fake(identifier: .init(rawValue: "test-server"), initial: info)

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        assertLightDarkSnapshots(
            of: NavigationView {
                ConnectionHardwareAddressesView(
                    viewModel: ConnectionURLViewModel(server: server, urlType: .internal)
                )
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 600)
        )
    }
}
