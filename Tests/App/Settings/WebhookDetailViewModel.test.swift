import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
@MainActor
struct WebhookDetailViewModelTests {
    private func makeServer(
        internalURL: URL?,
        externalURL: URL?,
        remoteUIURL: URL?,
        cloudhookURL: URL?,
        internalSSIDs: [String]? = nil
    ) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL,
                internalURL: internalURL,
                cloudhookURL: cloudhookURL,
                remoteUIURL: remoteUIURL,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: internalSSIDs,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(initial: info)
    }

    private func withNetworkState(_ state: NetworkState, _ body: () -> Void) {
        let previousCurrent = Current.connectivity.currentNetworkState
        let previousLastKnown = Current.connectivity.lastKnownNetworkState
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        defer {
            Current.connectivity.currentNetworkState = previousCurrent
            Current.connectivity.lastKnownNetworkState = previousLastKnown
            Current.connectivity.refreshNetworkInformation = previousRefresh
        }
        Current.connectivity.currentNetworkState = { state }
        Current.connectivity.lastKnownNetworkState = { state }
        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { state }
        }
        body()
    }

    @Test func listsCloudhookAndEveryConfiguredURLAsAWebhookEndpoint() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
            cloudhookURL: URL(string: "https://hooks.nabu.casa/cloudhook-id")
        )

        withNetworkState(NetworkState()) {
            let viewModel = WebhookDetailViewModel(server: server)

            #expect(viewModel.endpoints.map(\.source) == [.cloudhook, .internalURL, .remoteUI, .externalURL])
            #expect(viewModel.endpoints[0].url == URL(string: "https://hooks.nabu.casa/cloudhook-id"))
            #expect(
                viewModel.endpoints[1].url == URL(string: "http://internal.example.com:8123/api/webhook/webhook-id")
            )
            #expect(viewModel.endpoints[2].url == URL(string: "https://remote.ui.nabu.casa/api/webhook/webhook-id"))
            #expect(viewModel.endpoints[3].url == URL(string: "https://external.example.com/api/webhook/webhook-id"))
        }
    }

    @Test func cloudhookIsListedWithoutAURLWhenTheServerHasNoHomeAssistantCloud() {
        let server = makeServer(
            internalURL: nil,
            externalURL: URL(string: "https://external.example.com"),
            remoteUIURL: nil,
            cloudhookURL: nil
        )

        withNetworkState(NetworkState()) {
            let viewModel = WebhookDetailViewModel(server: server)

            #expect(viewModel.endpoints.map(\.source) == [.cloudhook, .externalURL])
            #expect(viewModel.endpoints[0].url == nil)
            #expect(viewModel.activeSource == .externalURL)
            #expect(viewModel.activeURL == URL(string: "https://external.example.com/api/webhook/webhook-id"))
        }
    }

    @Test func theCloudhookIsTheActiveEndpointWhileAwayFromTheInternalNetwork() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            remoteUIURL: nil,
            cloudhookURL: URL(string: "https://hooks.nabu.casa/cloudhook-id"),
            internalSSIDs: ["home"]
        )

        withNetworkState(NetworkState(ssid: "somewhere-else")) {
            let viewModel = WebhookDetailViewModel(server: server)

            #expect(viewModel.activeSource == .cloudhook)
            #expect(viewModel.activeURL == URL(string: "https://hooks.nabu.casa/cloudhook-id"))
        }
    }

    @Test func theInternalURLIsTheActiveEndpointWhileOnTheInternalNetwork() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            remoteUIURL: nil,
            cloudhookURL: URL(string: "https://hooks.nabu.casa/cloudhook-id"),
            internalSSIDs: ["home"]
        )

        withNetworkState(NetworkState(ssid: "home")) {
            let viewModel = WebhookDetailViewModel(server: server)

            #expect(viewModel.activeSource == .internalURL)
            #expect(viewModel.activeURL == URL(string: "http://internal.example.com:8123/api/webhook/webhook-id"))
        }
    }
}
