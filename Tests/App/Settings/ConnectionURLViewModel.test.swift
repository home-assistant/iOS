import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers what the URL editor derives from its fields: when the security level row applies, when Save
/// has something to save, and what a commit writes back.
@Suite(.serialized)
@MainActor
struct ConnectionURLViewModelTests {
    private func makeServer(internalURL: String?, securityLevel: ConnectionSecurityLevel = .mostSecure) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: securityLevel
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    @Test func securityLevelRowOnlyForPlainHTTPInternalURL() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let internalViewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        #expect(internalViewModel.showsSecurityLevel)

        internalViewModel.url = "https://internal.example.com:8123"
        #expect(!internalViewModel.showsSecurityLevel)

        internalViewModel.url = "not a url"
        #expect(!internalViewModel.showsSecurityLevel)

        let externalViewModel = ConnectionURLViewModel(server: server, urlType: .external)
        externalViewModel.url = "http://external.example.com"
        #expect(!externalViewModel.showsSecurityLevel)
    }

    @Test func hasChangesFollowsEdits() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        #expect(!viewModel.hasChanges)

        viewModel.ssids.append("OtherWifi")
        #expect(viewModel.hasChanges)
        viewModel.ssids.removeLast()
        #expect(!viewModel.hasChanges)

        viewModel.securityLevel = .lessSecure
        #expect(viewModel.hasChanges)
        viewModel.securityLevel = .mostSecure

        viewModel.localPush.toggle()
        #expect(viewModel.hasChanges)
        viewModel.localPush.toggle()

        viewModel.url = "http://other.example.com:8123"
        #expect(viewModel.hasChanges)
    }

    @Test func commitWritesSecurityLevelForInternalURLOnly() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")

        let internalViewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        internalViewModel.securityLevel = .lessSecure
        internalViewModel.commitAnyway(onSuccess: {})
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
        #expect(!internalViewModel.hasChanges)

        let externalViewModel = ConnectionURLViewModel(server: server, urlType: .external)
        externalViewModel.securityLevel = .undefined
        externalViewModel.commitAnyway(onSuccess: {})
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
    }
}
