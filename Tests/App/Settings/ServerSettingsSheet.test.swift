import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the sheet wrapper the server details screen presents its editors in: a navigation stack with
/// a close button around the given content.
@Suite(.sharedState)
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

    /// Given the namespace of the control that opened it, the sheet zooms out of that control.
    @Test func zoomsOutOfItsSourceControl() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let driver = await SwiftUIScreenDriver.show(ZoomingSheetHost(), inNavigationStack: false)
        defer { driver.close() }
        #expect(!driver.barButtons.isEmpty)
    }
}

/// Owns the namespace a zoom transition needs, the way the server details screen does.
private struct ZoomingSheetHost: View {
    @Namespace private var namespace

    var body: some View {
        ServerSettingsSheet(zoomSourceID: .internalURL, transitionNamespace: namespace, onClose: {}) {
            ConnectionURLsHowItWorksView(server: ServerFixture.standard)
        }
    }
}
