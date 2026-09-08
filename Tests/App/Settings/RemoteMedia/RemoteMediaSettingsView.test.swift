#if !targetEnvironment(macCatalyst)
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Serialized because both cases write the followed player to the shared settings store.
/// The suite itself carries no `@available`: swift-testing refuses to apply `@Test` to a function
/// marked unavailable, so each test checks at runtime, like the other version-gated suites here.
@Suite(.serialized)
@MainActor
struct RemoteMediaSettingsViewTests {
    @Test func emptySelection() async {
        guard #available(iOS 27.0, *) else { return }
        await snapshotSettings(following: nil)
    }

    @Test func followingAPlayer() async {
        guard #available(iOS 27.0, *) else { return }
        await snapshotSettings(following: .init(serverId: "server-1", entityId: "media_player.speaker"))
    }

    /// `testName` is defaulted at the call site, so each case still records under its own name.
    @available(iOS 27.0, *)
    private func snapshotSettings(following: RemoteMediaSelection?, testName: String = #function) async {
        let environment = AppEnvironment()
        environment.servers = FakeServerManager(initial: 0)
        await withCurrent(environment) {
            let previousSelection = Current.settingsStore.remoteMediaSelection
            defer { Current.settingsStore.remoteMediaSelection = previousSelection }
            Current.settingsStore.remoteMediaSelection = following
            let coordinator = RemoteMediaCoordinator()
            assertLightDarkSnapshots(
                of: NavigationStack { RemoteMediaSettingsView(coordinator: coordinator) },
                drawHierarchyInKeyWindow: true,
                testName: testName
            )
        }
    }
}
#endif
