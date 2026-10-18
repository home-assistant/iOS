import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the sheet wrapper the server details screen presents its editors in: a navigation stack with
/// a close button around the given content.
@Suite(.serialized)
@MainActor
struct ServerSettingsSheetTests {
    @Test func wrapsContentWithAClose() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        assertLightDarkSnapshots(
            of: ServerSettingsSheet(zoomSourceID: .internalURL, transitionNamespace: nil, onClose: {}) {
                ConnectionURLsHowItWorksView(server: ServerFixture.standard)
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 500)
        )
    }
}
