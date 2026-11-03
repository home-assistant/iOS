import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Covers the Home Assistant Link status shown under the connection error, both while it is used to
/// reach the server and after it has been turned off in the app.
@Suite(.serialized)
@MainActor
struct ConnectionErrorDetailsViewTests {
    private func makeServer(useCloud: Bool) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: nil,
                internalURL: URL(string: "http://internal.example.com:8123"),
                cloudhookURL: nil,
                remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    @Test func connectionErrorDetailsWithHomeAssistantLinkInUse() async throws {
        assertLightDarkSnapshots(
            of: ConnectionErrorDetailsView(server: makeServer(useCloud: true), error: URLError(.timedOut)),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1600)
        )
    }

    @Test func connectionErrorDetailsWithHomeAssistantLinkTurnedOff() async throws {
        assertLightDarkSnapshots(
            of: ConnectionErrorDetailsView(server: makeServer(useCloud: false), error: URLError(.timedOut)),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1600)
        )
    }
}
