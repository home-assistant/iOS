import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the URL editor as the server details screen presents it, and the close that clears both
/// editing flags.
@Suite(.sharedState)
@MainActor
struct ServerURLEditorSheetTests {
    @Test func externalEditorInASheet() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let viewModel = ConnectionSettingsViewModel(server: ServerFixture.standard)
        viewModel.isEditingExternalURL = true
        assertLightDarkSnapshots(
            of: ServerURLEditorSheet(viewModel: viewModel, urlType: .external, transitionNamespace: nil),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 600)
        )
    }

    /// Closing the editor stops editing both addresses.
    @Test func closingStopsEditingBothURLs() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let viewModel = ConnectionSettingsViewModel(server: ServerFixture.standard)
        viewModel.isEditingInternalURL = true
        viewModel.isEditingExternalURL = true
        let driver = await SwiftUIScreenDriver.show(
            ServerURLEditorSheet(viewModel: viewModel, urlType: .internal, transitionNamespace: nil),
            inNavigationStack: false
        )
        defer { driver.close() }

        let item = driver.navigationController?.topViewController?.navigationItem
        let leading = (item?.leftBarButtonItems ?? []) + (item?.leadingItemGroups ?? []).flatMap(\.barButtonItems)
        let close = try #require(driver.barButtons.firstIndex { button in leading.contains { $0 === button } })
        await driver.tapBarButton(close)
        #expect(!viewModel.isEditingInternalURL)
        #expect(!viewModel.isEditingExternalURL)
    }
}
