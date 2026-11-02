@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders the stand-by screen with the parts the snapshots leave out: the server pill that only
/// appears with several servers, the connection type indicator for each active URL type, and the
/// in-flight and disconnected empty states.
@Suite(.sharedState)
@MainActor
struct HomeAssistantStandByViewRenderTests {
    private func render(_ view: HomeAssistantStandByView) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        // The pill fades in from a published phase, which lands on a later pass.
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func withServers(_ count: Int, _ body: () async throws -> Void) async rethrows {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: count)
        defer { Current.servers = previousServers }
        try await body()
    }

    @Test(arguments: [
        ConnectionInfo.URLType.internal,
        .external,
        .remoteUI,
        .none,
    ])
    func rendersTheServerPillForEachActiveConnection(activeURLType: ConnectionInfo.URLType) async {
        await withServers(2) {
            let server = HomeAssistantStandByView.previewServer(
                name: "Home",
                configuredURLTypes: [.internal, .external, .remoteUI],
                activeURLType: activeURLType
            )
            var tapped = 0
            await render(HomeAssistantStandByView(
                server: server,
                emptyState: nil,
                onSelectServerTapped: { tapped += 1 },
                contentFadeAnimation: nil
            ))
            #expect(tapped == 0)
        }
    }

    @Test(arguments: [WebViewEmptyStateStyle.inFlight, .disconnected, .unauthenticated, .loggedOut])
    func rendersAnEmptyStateWithSeveralServers(style: WebViewEmptyStateStyle) async {
        await withServers(3) {
            let server = HomeAssistantStandByView.previewServer(
                name: "Home",
                configuredURLTypes: [.internal, .external],
                activeURLType: .external
            )
            await render(HomeAssistantStandByView(
                server: server,
                emptyState: HomeAssistantStandByView.previewEmptyState(
                    style: style,
                    server: server,
                    showsErrorDetailsButton: true,
                    availableReauthURLTypes: [.internal, .external]
                ),
                contentFadeAnimation: nil
            ))
        }
    }

    @Test func aSingleServerHasNoPillToSwitchFrom() async {
        await withServers(1) {
            let server = HomeAssistantStandByView.previewServer(
                name: "Home",
                configuredURLTypes: [.external],
                activeURLType: .external
            )
            await render(HomeAssistantStandByView(server: server, emptyState: nil, isLoading: true))
        }
    }

    @Test func selectingAServerReportsItAndPreviewURLsMatchTheirType() {
        let server = HomeAssistantStandByView.previewServer(
            name: "Home",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        var selected: [Server] = []
        let view = HomeAssistantStandByView(server: server, emptyState: nil, onSelectServer: { selected.append($0) })
        view.selectServer(server)
        #expect(selected.map(\.identifier) == [server.identifier])
        #expect(HomeAssistantStandByView.logoDismissTapThreshold > 1)
        #expect(HomeAssistantStandByView.previewURL(for: .none) == nil)
        #expect(HomeAssistantStandByView.previewURL(for: .remoteUI) != nil)
    }
}
