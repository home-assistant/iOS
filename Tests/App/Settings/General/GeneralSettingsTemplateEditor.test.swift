import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Renders the menu bar template editor against a mocked server connection: each template it sends
/// is answered with a rendered string, an error or something unexpected, and the result is saved.
///
/// `.sharedState`: the test swaps `Current.servers` and the cached API, and writes the menu template
/// preference.
@Suite(.sharedState)
@MainActor
struct GeneralSettingsTemplateEditorTests {
    private func withServer(_ body: (Server, HAMockConnection) async throws -> Void) async throws {
        let prefs = Current.settingsStore.prefs
        let previousServerKey = prefs.string(forKey: "menuItemTemplate-server")
        let previousTemplate = prefs.string(forKey: "menuItemTemplate")
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 1)
        let server = manager.all[0]
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        Current.servers = manager
        defer {
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
            prefs.setValue(previousServerKey, forKey: "menuItemTemplate-server")
            prefs.setValue(previousTemplate, forKey: "menuItemTemplate")
        }
        try await body(server, connection)
    }

    /// Answers the newest template request; earlier ones were cancelled by the editor.
    private func answer(
        _ connection: HAMockConnection,
        with result: Result<HAData, HAError>,
        harness: SettingsScreenHarness
    ) async -> Bool {
        guard await harness.waitUntil(timeout: 5, { !connection.pendingRequests.isEmpty }) else { return false }
        let request = connection.pendingRequests.removeLast()
        connection.pendingRequests.removeAll()
        request.completion(result)
        await harness.settle()
        return true
    }

    @Test func rendersEachKindOfAnswerAndSaves() async throws {
        try await withServer { server, connection in
            Current.settingsStore.menuItemTemplate = (server, "{{ states('sun.sun') }}")
            let harness = await SettingsScreenHarness.show(GeneralSettingsTemplateEditor())
            // The template field and the preview (a single server needs no picker).
            await #expect(harness.waitUntil { harness.rows.count >= 2 })

            await #expect(answer(connection, with: .success(.primitive("above_horizon")), harness: harness))
            await harness.type("{{ now() }}")
            await #expect(answer(connection, with: .failure(.internal(debugDescription: "boom")), harness: harness))
            await harness.type("{{ 1 }}")
            await #expect(answer(connection, with: .success(.dictionary(["a": 1])), harness: harness))
            await harness.type("{{ 2 }}")
            await #expect(answer(connection, with: .success(.empty), harness: harness))

            await harness.tapBarButton()
            #expect(Current.settingsStore.menuItemTemplate?.template == "{{ 2 }}")
            await harness.close()
        }
    }

    @Test func withoutAServerOnlyThePickerShows() async throws {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)
        defer { Current.servers = previousServers }
        let harness = await SettingsScreenHarness.show(GeneralSettingsTemplateEditor())
        #expect(harness.rows.count <= 1)
        // Saving needs a server, so nothing happens.
        await harness.tapBarButton()
        await harness.close()
    }
}
