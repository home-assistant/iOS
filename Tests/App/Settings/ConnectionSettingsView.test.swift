import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import Testing

/// Covers the per-server connection screen, whose details section now carries the
/// "Understand Internal vs External URLs" row under the two URL rows.
@Suite(.serialized)
@MainActor
struct ConnectionSettingsViewTests {
    @Test func serverConnectionScreen() async throws {
        try await assertServerConnectionScreen()
    }

    @Test func settingsSearchFindsReauthenticate() {
        #expect(ConnectionSettingsView.settingsSearchEntries.contains { $0.matches(searchQuery: "re-auth") })
    }

    /// Open hands the server to the coordinator; outside a window's Settings sheet that is the app-wide one.
    @Test func openingTheServerActivatesIt() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)
        let server = Server.fake()
        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)

        await withCheckedContinuation { continuation in
            coordinator.onActivateServer = { continuation.resume() }
            ConnectionSettingsView(server: server).openServer()
        }

        #expect(coordinator.activatedServers.map(\.identifier) == [server.identifier])
    }

    /// While a Re-authenticate runs, its row shows progress instead of the button title.
    @Test func serverConnectionScreenWhileReauthenticating() async throws {
        let reauthentication = ServerReauthenticationModel()
        // The sign in stays on its first step, so the row stays busy without presenting anything.
        reauthentication.reauthenticator.clientCertificateRequirement = { _ in Promise<Bool>.pending().promise }
        try await assertServerConnectionScreen(reauthentication: reauthentication) { server in
            reauthentication.reauthenticate(server, using: .external)
        }
    }

    private func assertServerConnectionScreen(
        reauthentication: ServerReauthenticationModel? = nil,
        prepare: (Server) -> Void = { _ in },
        testName: String = #function
    ) async throws {
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

        prepare(server)

        assertLightDarkSnapshots(
            of: NavigationView { ConnectionSettingsView(server: server, reauthentication: reauthentication) },
            drawHierarchyInKeyWindow: true,
            // Taller than a device so the whole details section is captured, not only the part
            // that fits above the fold.
            layout: .fixed(width: 390, height: 2600),
            testName: testName
        )
    }
}
