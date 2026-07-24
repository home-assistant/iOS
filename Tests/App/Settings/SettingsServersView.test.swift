@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

struct SettingsServersViewTests {
    @MainActor
    @Test func settingsServersScreen() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        // Two servers so the location-based switching toggle and its footer are visible.
        Current.servers = FakeServerManager(initial: 2)
        assertLightDarkSnapshots(of: NavigationView { SettingsServersView() }, drawHierarchyInKeyWindow: true)
    }
}
