@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

struct ServerSwitchingSettingsViewTests {
    @MainActor
    @Test func serverSwitchingScreen() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        // Two servers so the location-based switching toggle and its footer are visible.
        Current.servers = FakeServerManager(initial: 2)
        assertLightDarkSnapshots(
            of: NavigationView { ServerSwitchingSettingsView() },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor
    @Test func serverSwitchingScreenWithClosestServer() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)
        assertLightDarkSnapshots(
            of: NavigationView {
                ServerSwitchingSettingsView(
                    viewModel: ServerSwitchingSettingsViewModel(
                        closestServerDescription: "Fake Server · 1.2 km",
                        closestServerSource: .location(distance: 1200)
                    )
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor
    @Test func serverSwitchingScreenWithClosestServerOnHomeNetwork() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)
        // Matched by Wi-Fi: no distance in the value, and the badge says where it came from.
        assertLightDarkSnapshots(
            of: NavigationView {
                ServerSwitchingSettingsView(
                    viewModel: ServerSwitchingSettingsViewModel(
                        closestServerDescription: "Fake Server",
                        closestServerSource: .homeNetwork
                    )
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
