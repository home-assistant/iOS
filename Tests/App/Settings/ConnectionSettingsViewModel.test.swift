import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Stands in for the database updater so a Sync in a test never reaches the network.
private final class IdleAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    private(set) var updatedServers: [Server] = []

    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
        updatedServers.append(server)
    }
}

/// Covers what the server screen's view model derives for the details row: the URLs, which one is in
/// use, the Sync button's in-flight state, and the invitation link behind the share button.
@Suite(.serialized)
@MainActor
struct ConnectionSettingsViewModelTests {
    private func makeServer(
        identifier: String = "test-server",
        internalURL: String?,
        externalURL: String?,
        remoteUIURL: String? = nil,
        useCloud: Bool = false
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL.flatMap(URL.init(string:)),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: remoteUIURL.flatMap(URL.init(string:)),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .lessSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        return Server.fake(identifier: .init(rawValue: identifier), initial: info)
    }

    private func withTestWorld<T>(_ body: () async throws -> T) async rethrows -> T {
        let previousServers = Current.servers
        let previousUpdater = Current.appDatabaseUpdater
        defer {
            Current.servers = previousServers
            Current.appDatabaseUpdater = previousUpdater
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.appDatabaseUpdater = IdleAppDatabaseUpdater()
        return try await body()
    }

    @Test func urlsAndActiveTypeFollowTheServer() async {
        await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)

            #expect(viewModel.internalURL == "http://internal.example.com:8123")
            #expect(viewModel.externalURL == nil)
            #expect(viewModel.externalAddress == nil)
            #expect(!viewModel.isUsingCloud)
            #expect(viewModel.activeURLType == .internal)
            #expect(viewModel.version == "2024.1")
        }
    }

    @Test func cloudReplacesTheExternalURL() async {
        await withTestWorld {
            let server = makeServer(
                internalURL: nil,
                externalURL: "https://external.example.com",
                remoteUIURL: "https://example.ui.nabu.casa",
                useCloud: true
            )
            let viewModel = ConnectionSettingsViewModel(server: server)

            #expect(viewModel.isUsingCloud)
            #expect(viewModel.externalURL == L10n.Settings.ConnectionSection.HomeAssistantCloud.title)
            #expect(viewModel.externalAddress == "https://example.ui.nabu.casa")
            #expect(viewModel.activeURLType == .remoteUI)
        }
    }

    @Test func syncEndsWhenThisServerFinishes() async throws {
        try await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let otherServer = makeServer(identifier: "other", internalURL: "http://other.example.com", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)
            #expect(!viewModel.isSyncing)

            viewModel.updateAppDatabase()
            #expect(viewModel.isSyncing)

            AppDatabaseUpdaterUserInfo.postDidFinish(serverId: otherServer.identifier.rawValue)
            try await Task.sleep(for: .milliseconds(50))
            #expect(viewModel.isSyncing)

            AppDatabaseUpdaterUserInfo.postDidFinish(serverId: server.identifier.rawValue)
            try await Task.sleep(for: .milliseconds(50))
            #expect(!viewModel.isSyncing)
        }
    }

    @Test func invitationURLNeedsAnAddressToInviteTo() async {
        await withTestWorld {
            let shareable = ConnectionSettingsViewModel(
                server: makeServer(internalURL: nil, externalURL: "https://external.example.com")
            )
            #expect(shareable.invitationURL() != nil)
            #expect(shareable.canShareServer)

            let unreachable = ConnectionSettingsViewModel(server: makeServer(internalURL: nil, externalURL: nil))
            #expect(unreachable.invitationURL() == nil)
            #expect(!unreachable.canShareServer)
        }
    }
}
