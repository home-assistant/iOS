import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the explainer sheet the Troubleshooting button opens.
@Suite(.serialized)
@MainActor
struct ServerHowItWorksSheetTests {
    @Test func explainerInASheet() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let viewModel = ConnectionSettingsViewModel(server: ServerFixture.standard)
        viewModel.isShowingHowItWorks = true
        assertLightDarkSnapshots(
            of: ServerHowItWorksSheet(viewModel: viewModel),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 500)
        )
    }
}
