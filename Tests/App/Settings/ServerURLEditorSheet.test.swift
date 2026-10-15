import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the URL editor as the server details screen presents it, and the close that clears both
/// editing flags.
@Suite(.serialized)
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
}
