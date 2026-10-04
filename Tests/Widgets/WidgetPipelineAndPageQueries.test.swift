import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// The Assist pipeline and page pickers, read from an in-memory copy of the local mirrors the app
/// keeps of each server's pipelines and panels.
///
/// Serialized because every test swaps the database and the servers in `Current`.
@Suite(.serialized)
struct WidgetPipelineAndPageQueriesTests {
    private static let serverId = "pipeline-server"

    @Test func pipelineQueryResolvesPreferredLegacyAndStoredPipelines() async throws {
        try await withSeededDatabase {
            let query = AssistPipelineEntityQuery()

            let entities = try await query.entities(for: [
                AssistPipelineEntity.preferredIdPrefix + Self.serverId,
                "",
                "pipeline-2",
                "unknown",
            ])

            #expect(entities.count == 3)
            #expect(entities[0].isPreferred)
            #expect(entities[0].serverId == Self.serverId)
            #expect(entities[0].pipelineId == nil)
            // The legacy empty id resolves to the first server's preferred pipeline.
            #expect(entities[1].isPreferred)
            #expect(entities[1].serverId == Self.serverId)
            #expect(entities[2].id == "pipeline-2")
            #expect(entities[2].name == "Kitchen")
            #expect(entities[2].pipelineId == "pipeline-2")
            #expect(!entities[2].isPreferred)
            _ = entities[2].displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "kit")

            let defaultResult = await query.defaultResult()
            #expect(defaultResult?.id == AssistPipelineEntity.preferredIdPrefix + Self.serverId)
        }
    }

    @Test func pipelineQueryWithoutServersHasNoDefault() async throws {
        try await withSeededDatabase {
            Current.servers = FakeServerManager()
            let query = AssistPipelineEntityQuery()

            let entities = try await query.entities(for: ["", "pipeline-1"])

            #expect(entities.isEmpty)
            let defaultResult = await query.defaultResult()
            #expect(defaultResult == nil)
        }
    }

    @Test func pipelineQueryWithoutItsTableThrows() async throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try DatabaseQueue(path: ":memory:")
        Current.database = { database }

        await #expect(throws: (any Error).self) {
            _ = try await AssistPipelineEntityQuery().suggestedEntities()
        }
    }

    @Test func pageQueryResolvesStoredPanels() async throws {
        try await withSeededDatabase {
            let query = PageAppEntityQuery()
            let overviewId = PageAppEntity.makeId(serverId: Self.serverId, panelPath: "lovelace")

            let entities = try await query.entities(for: [overviewId, "missing"])

            #expect(entities.map(\.id) == [overviewId])
            let page = try #require(entities.first)
            #expect(page.serverId == Self.serverId)
            #expect(page.panel.title == "Overview")
            #expect(page.panel.path == "lovelace")
            _ = page.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "energy")
        }
    }

    // MARK: - Helpers

    private func withSeededDatabase(_ body: () async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let database = try DatabaseQueue(path: ":memory:")
        try AssistPipelinesTable().createIfNeeded(database: database)
        try AppPanelTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        try await database.write { db in
            try AssistPipelines(
                serverId: Self.serverId,
                preferredPipeline: "pipeline-1",
                pipelines: [
                    Pipeline(id: "pipeline-1", name: "Home"),
                    Pipeline(id: "pipeline-2", name: "Kitchen"),
                ]
            ).insert(db)
            try AppPanel(
                id: "\(Self.serverId)-lovelace",
                serverId: Self.serverId,
                title: "Overview",
                path: "lovelace",
                component: "lovelace",
                showInSidebar: true
            ).insert(db)
            try AppPanel(
                id: "\(Self.serverId)-energy",
                serverId: Self.serverId,
                title: "Energy",
                path: "energy",
                component: "energy",
                showInSidebar: true
            ).insert(db)
        }

        try await body()
    }
}
