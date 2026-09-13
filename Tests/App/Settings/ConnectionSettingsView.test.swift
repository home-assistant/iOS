import CoreLocation
import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Covers the per-server connection screen, whose details section now carries the
/// "Understand Internal vs External URLs" row under the two URL rows.
@Suite(.serialized)
@MainActor
struct ConnectionSettingsViewTests {
    @Test func serverConnectionScreen() async throws {
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
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        let server = Server.fake(identifier: .init(rawValue: "test-server"), initial: info)

        let previousServers = Current.servers
        let previousDeviceName = Current.device.deviceName
        defer {
            Current.servers = previousServers
            Current.device.deviceName = previousDeviceName
        }
        Current.servers = FakeServerManager(initial: 0)
        // The Device Name row falls back to this device's name, which differs per machine.
        Current.device.deviceName = { "iPhone" }

        assertLightDarkSnapshots(
            of: NavigationView { ConnectionSettingsView(server: server) },
            drawHierarchyInKeyWindow: true,
            // Taller than a device so the whole details section is captured, not only the part
            // that fits above the fold.
            layout: .fixed(width: 390, height: 2600)
        )
    }
}
