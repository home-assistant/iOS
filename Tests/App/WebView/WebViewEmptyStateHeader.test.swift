@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct WebViewEmptyStateHeaderTests {
    @MainActor @Test func serverSelectionOffsetLeavesTheAccessoriesInPlace() async throws {
        guard #available(iOS 18.0, *) else { return }

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)

        assertLightDarkSnapshots(
            of: makeHeader(),
            layout: .fixed(width: 390, height: 76),
            named: "empty-state-header-server-selection-offset"
        )
    }

    @MainActor @Test func catalystServerSelectionOffsetLeavesTheAccessoriesInPlace() async throws {
        guard #available(iOS 18.0, *) else { return }

        let previousServers = Current.servers
        let previousIsCatalyst = Current.isCatalyst
        defer {
            Current.servers = previousServers
            Current.isCatalyst = previousIsCatalyst
        }
        Current.servers = FakeServerManager(initial: 2)
        Current.isCatalyst = true

        assertLightDarkSnapshots(
            of: makeHeader(),
            layout: .fixed(width: 390, height: 76),
            named: "empty-state-header-catalyst-server-selection-offset"
        )
    }

    private func makeHeader() -> WebViewEmptyStateHeader {
        WebViewEmptyStateHeader(
            style: .unauthenticated,
            server: Current.servers.all.first ?? ServerFixture.standard,
            isLoading: false,
            showsServerSelection: true,
            showsErrorDetailsButton: false,
            settingsAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {},
            serverSelectionHorizontalOffset: 42
        )
    }
}
