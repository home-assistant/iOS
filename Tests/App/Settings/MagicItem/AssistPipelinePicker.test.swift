import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Opens the Assist pipeline picker's sheet over cached pipelines and picks one, and shows what it
/// offers when nothing is cached and no server can be asked.
///
/// `.sharedState`: the test swaps `Current.database` and `Current.servers`.
@Suite(.sharedState)
@MainActor
struct AssistPipelinePickerTests {
    private final class Selection {
        var serverId: String?
        var pipelineId: String?
    }

    private func picker(_ selection: Selection) -> some View {
        // In a list the picker's button is the row, so tapping the row opens the sheet.
        List {
            AssistPipelinePicker(
                selectedServerId: Binding(get: { selection.serverId }, set: { selection.serverId = $0 }),
                selectedPipelineId: Binding(get: { selection.pipelineId }, set: { selection.pipelineId = $0 })
            )
        }
    }

    @Test func picksACachedPipeline() async throws {
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 2)
        Current.servers = manager
        defer { Current.servers = previousServers }
        let serverId = manager.all[0].identifier.rawValue

        try await SettingsTestDatabase.with({ db in
            try AssistPipelines(
                serverId: serverId,
                preferredPipeline: "local",
                pipelines: [.init(id: "local", name: "Home Assistant"), .init(id: "cloud", name: "Cloud")]
            ).insert(db)
            try AssistPipelines(serverId: "unknown-server", preferredPipeline: "x", pipelines: []).insert(db)
        }) { _ in
            let selection = Selection()
            selection.serverId = serverId
            selection.pipelineId = "cloud"
            let harness = await SettingsScreenHarness.show(picker(selection), inNavigationStack: false)

            await harness.tapRow(IndexPath(item: 0, section: 0))
            await #expect(harness.waitUntil(timeout: 5) { harness.presented != nil })
            await #expect(harness.waitUntil { harness.rows.count == 3 })

            await harness.search("cloud")
            await harness.search("")
            await harness.tapRow(IndexPath(item: 1, section: 0))
            #expect(selection.pipelineId == "local")
            #expect(selection.serverId == serverId)
            await #expect(harness.waitUntil(timeout: 5) { harness.presented == nil })
            await harness.close()
        }
    }

    @Test func showsNoPipelinesWithoutCacheOrServers() async throws {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)
        defer { Current.servers = previousServers }

        try await SettingsTestDatabase.with { _ in
            let selection = Selection()
            let harness = await SettingsScreenHarness.show(picker(selection), inNavigationStack: false)
            await harness.tapRow(IndexPath(item: 0, section: 0))
            await #expect(harness.waitUntil(timeout: 5) { harness.presented != nil })
            await #expect(harness.waitUntil { harness.rows.count == 1 })
            // The reload button asks every server again; there are none, so it settles at once.
            await harness.tapBarButton(0)
            await harness.tapBarButton(1)
            #expect(selection.pipelineId == nil)
            await harness.close()
        }
    }

    /// With nothing readable in the cache, the picker asks every server as soon as it appears and
    /// settles once they answered, even when they could not.
    @Test func asksEveryServerWhenTheCacheCannotBeRead() async throws {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.servers = servers
        Current.setCachedApi(api, for: server.identifier)
        defer {
            connection.pendingRequests.removeAll()
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
        }

        try await SettingsTestDatabase.closed {
            let selection = Selection()
            let driver = await SwiftUIScreenDriver.show(picker(selection), inNavigationStack: false)
            defer { driver.close() }

            await #expect(driver.waitUntil { !connection.pendingRequests.isEmpty })
            let request = try #require(connection.pendingRequests.first)
            connection.pendingRequests.removeAll()
            request.completion(.failure(.internal(debugDescription: "offline")))
            await driver.settle()
            #expect(selection.pipelineId == nil)
        }
    }
}
