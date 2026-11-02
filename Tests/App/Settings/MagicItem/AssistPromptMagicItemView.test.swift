import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The Assist prompt editor hands back an edited prompt with its pipeline once there is a title and
/// a prompt; a new one starts empty, so there is nothing to add yet.
/// Shared state: swaps `Current.database` and `Current.servers`, which the pipeline picker reads.
@MainActor
@Suite(.sharedState)
struct AssistPromptMagicItemViewTests {
    @Test func editingAPromptHandsItBack() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers

        // With the fake server's pipelines cached, neither picker asks the server for them, so no request
        // outlives the test and calls back into a later test's environment.
        let seedPipelines: (Database) throws -> Void = { db in
            try AssistPipelines(
                serverId: servers.all[0].identifier.rawValue,
                preferredPipeline: "prompt",
                pipelines: [.init(id: "prompt", name: "Home Assistant")]
            ).save(db)
        }
        try await SettingsTestDatabase.with(seedPipelines) { _ in
            var saved: [MagicItem] = []
            let item = MagicItem(
                id: "prompt",
                serverId: "server",
                type: .assistPrompt,
                displayText: "Good night",
                assistPrompt: "Turn everything off"
            )
            let driver = await SwiftUIScreenDriver.show(
                AssistPromptMagicItemView(mode: .edit, item: item) { saved.append($0) }
            )
            defer { driver.close() }
            let pressed = await driver.tapBarButton(titled: L10n.MagicItem.edit)
            #expect(pressed)
            #expect(saved.first?.displayText == "Good night")
            #expect(saved.first?.assistPipelineId == "prompt")

            let adding = await SwiftUIScreenDriver.show(AssistPromptMagicItemView(mode: .add) { saved.append($0) })
            defer { adding.close() }
            #expect(adding.barButtons.first?.title == L10n.MagicItem.add)
        }
    }
}
