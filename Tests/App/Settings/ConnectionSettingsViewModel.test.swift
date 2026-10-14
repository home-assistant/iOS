import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
@MainActor
struct ConnectionSettingsViewModelTests {
    @Test func externalURLShowsHomeAssistantLinkWhenItIsInUse() {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
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
        info.connection.useCloud = true
        let server = Server.fake(identifier: .init(rawValue: "test-server"), initial: info)

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let viewModel = ConnectionSettingsViewModel(server: server)

        #expect(viewModel.externalURL == "Home Assistant Link")
    }
}
