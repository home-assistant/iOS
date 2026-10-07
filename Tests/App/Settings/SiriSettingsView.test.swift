@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@Suite(.serialized)
struct SiriSettingsViewSnapshotTests {
    @MainActor
    @Test func siriSettingsWithAConfigureLinkUnderExposedServers() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let home = manager.addFake()
        home.update { $0.remoteName = "Home" }
        let cabin = manager.addFake()
        cabin.update { $0.remoteName = "Cabin" }
        Current.servers = manager
        let serverIds = [home.identifier.rawValue, cabin.identifier.rawValue]
        try await SiriTestSeeding.clear(serverIds: serverIds)
        SiriServerExposure.setExposed(false, serverId: cabin.identifier.rawValue)

        assertLightDarkSnapshots(of: SiriSettingsView(), drawHierarchyInKeyWindow: true)

        try await SiriTestSeeding.clear(serverIds: serverIds)
    }
}
