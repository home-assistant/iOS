import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Serialized: the test replaces the process-wide `Current.database`.
@Suite(.serialized)
@MainActor
struct AssistPipelineAddListSnapshotTests {
    /// The cached pipelines are listed per server, with a reload button in the toolbar to fetch
    /// pipelines created since they were cached.
    @Test func listsCachedPipelinesWithReloadButton() throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }

        let database = try DatabaseQueue(path: ":memory:")
        try AssistPipelinesTable().createIfNeeded(database: database)
        try database.write { db in
            try AssistPipelines(
                serverId: "server",
                preferredPipeline: "local",
                pipelines: [
                    .init(id: "local", name: "Home Assistant"),
                    .init(id: "cloud", name: "Home Assistant Cloud"),
                ]
            ).save(db)
        }
        Current.database = { database }

        assertLightDarkSnapshots(
            of: NavigationView { AssistPipelineAddList { _ in } }.navigationViewStyle(.stack),
            drawHierarchyInKeyWindow: true
        )
    }
}
