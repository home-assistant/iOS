@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

struct WebViewEmptyStateHeaderTests {
    @MainActor @Test func serverSelectionOffsetLeavesTheAccessoriesInPlace() async throws {
        guard #available(iOS 18.0, *) else { return }

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)

        assertLightDarkSnapshots(
            of: makeHeader(),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 76),
            named: "empty-state-header-server-selection-offset"
        )
    }

    @MainActor @Test func serverSwitcherOffsetLeavesTheAccessoriesInPlace() async throws {
        guard #available(iOS 18.0, *) else { return }

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)

        assertLightDarkSnapshots(
            of: makeHeader(serverSwitcherAction: {}),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 76),
            named: "empty-state-header-server-switcher-offset"
        )
    }

    @MainActor @Test func serverSwitcherWithANamespaceLaysOut() async {
        let controller = UIHostingController(rootView: NamespacedHeader(header: makeHeader))
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 76))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        window.layoutIfNeeded()
        try? await Task.sleep(for: .seconds(0.5))

        #expect(controller.view.bounds.size == CGSize(width: 390, height: 76))
    }

    private func makeHeader(
        serverSwitcherAction: (() -> Void)? = nil,
        serverSelectionNamespace: Namespace.ID? = nil
    ) -> WebViewEmptyStateHeader {
        WebViewEmptyStateHeader(
            style: .unauthenticated,
            server: Current.servers.all.first ?? ServerFixture.standard,
            isLoading: false,
            showsServerSelection: true,
            showsErrorDetailsButton: false,
            settingsAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {},
            serverSelectionHorizontalOffset: 42,
            serverSwitcherAction: serverSwitcherAction,
            serverSelectionNamespace: serverSelectionNamespace
        )
    }

    private struct NamespacedHeader: View {
        let header: ((() -> Void)?, Namespace.ID?) -> WebViewEmptyStateHeader
        @Namespace private var namespace

        var body: some View {
            header({}, namespace)
        }
    }
}
