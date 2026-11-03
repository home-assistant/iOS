import Foundation
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the webhook detail screen out for a server with every kind of URL and checks reachability
/// against stubbed responses, both through the view model and through the screen's buttons.
///
/// `.sharedState`: the test swaps `Current.connectivity` and installs process-wide HTTP stubs.
@Suite(.sharedState)
@MainActor
struct WebhookDetailViewRenderTests {
    private static let reachableHost = "reachable.webhook-detail.test"
    private static let unreachableHost = "unreachable.webhook-detail.test"

    private func makeServer(cloudhook: Bool) -> Server {
        let info = ServerInfo(
            name: "Webhook Server",
            connection: .init(
                externalURL: URL(string: "https://\(Self.reachableHost)"),
                internalURL: URL(string: "http://\(Self.unreachableHost):8123"),
                cloudhookURL: cloudhook ? URL(string: "https://\(Self.reachableHost)/cloudhook-id") : nil,
                remoteUIURL: URL(string: "https://\(Self.reachableHost)/remote"),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
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

    private func withStubs(_ body: () async throws -> Void) async rethrows {
        let previousCurrent = Current.connectivity.currentNetworkState
        let previousLastKnown = Current.connectivity.lastKnownNetworkState
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        Current.connectivity.currentNetworkState = { NetworkState() }
        Current.connectivity.lastKnownNetworkState = { NetworkState() }
        Current.connectivity.refreshNetworkInformation = {}
        let reachable = stub(condition: isHost(Self.reachableHost)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 204, headers: nil)
        }
        let unreachable = stub(condition: isHost(Self.unreachableHost)) { _ in
            HTTPStubsResponse(error: URLError(.cannotConnectToHost))
        }
        defer {
            HTTPStubs.removeStub(reachable)
            HTTPStubs.removeStub(unreachable)
            Current.connectivity.currentNetworkState = previousCurrent
            Current.connectivity.lastKnownNetworkState = previousLastKnown
            Current.connectivity.refreshNetworkInformation = previousRefresh
        }
        try await body()
    }

    @Test func reachabilityResultsDescribeTheOutcome() {
        #expect(WebhookReachabilityResult.reachable(statusCode: 204).isReachable)
        #expect(WebhookReachabilityResult.reachable(statusCode: nil).isReachable)
        #expect(!WebhookReachabilityResult.unreachable(message: "offline").isReachable)
        #expect(WebhookReachabilityResult.reachable(statusCode: 204).localizedDescription.contains("204"))
        #expect(!WebhookReachabilityResult.reachable(statusCode: nil).localizedDescription.isEmpty)
        #expect(WebhookReachabilityResult.unreachable(message: "offline").localizedDescription.contains("offline"))
    }

    @Test func checksReachabilityOfEachEndpoint() async {
        await withStubs {
            let viewModel = WebhookDetailViewModel(server: makeServer(cloudhook: false))
            await viewModel.refresh()
            #expect(viewModel.activeURL != nil)
            #expect(!viewModel.activeSourceTitle.isEmpty)

            for endpoint in viewModel.endpoints {
                await viewModel.checkReachability(for: endpoint)
                #expect(!viewModel.isChecking(endpoint))
                viewModel.copyURL(of: endpoint)
            }
            viewModel.copyActiveURL()

            let byURL = Dictionary(uniqueKeysWithValues: viewModel.endpoints.map { ($0.source, $0) })
            // The cloudhook has no URL here, so there is nothing to check.
            #expect(byURL[.cloudhook].flatMap(viewModel.result(for:)) == nil)
            #expect(byURL[.externalURL].flatMap(viewModel.result(for:)) == .reachable(statusCode: 204))
            #expect(byURL[.internalURL].flatMap(viewModel.result(for:))?.isReachable == false)
        }
    }

    @Test func rendersEveryEndpointAndRunsItsChecks() async {
        await withStubs {
            let harness = await SettingsScreenHarness.show(WebhookDetailView(server: makeServer(cloudhook: true)))
            // The active URL section, then one section per endpoint.
            await #expect(harness.waitUntil { (harness.list?.numberOfSections ?? 0) >= 5 })
            let before = harness.rows.count

            // Each endpoint's third row checks its reachability; a result row then joins the section.
            let sections = harness.list?.numberOfSections ?? 0
            for section in 1 ..< sections {
                await harness.tapRow(IndexPath(item: 2, section: section))
            }
            await #expect(harness.waitUntil { harness.rows.count >= before + sections - 1 })
            // Copy buttons.
            await harness.tapRow(IndexPath(item: 2, section: 0))
            await harness.tapRow(IndexPath(item: 1, section: 1))
            await harness.close()
        }
    }
}
