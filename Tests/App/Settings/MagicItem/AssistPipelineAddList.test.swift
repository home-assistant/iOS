import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// With nothing readable in the cache, the list asks every server for its pipelines and settles once
/// they answered, even when they could not.
///
/// `.sharedState`: the test swaps `Current.servers`, `Current.database` and the cached API.
@Suite(.sharedState)
@MainActor
struct AssistPipelineAddListTests {
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
            let driver = await SwiftUIScreenDriver.show(AssistPipelineAddList { _ in })
            defer { driver.close() }

            await #expect(driver.waitUntil { !connection.pendingRequests.isEmpty })
            let request = try #require(connection.pendingRequests.first)
            #expect(request.request.type.command == "assist_pipeline/pipeline/list")
            connection.pendingRequests.removeAll()
            request.completion(.failure(.internal(debugDescription: "offline")))

            // Done loading, with nothing to list.
            await #expect(driver.waitUntil { driver.rows.count == 1 })
        }
    }
}
