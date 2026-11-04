import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Serialized: the test replaces the process-wide `Current.database`.
@Suite(.sharedState)
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

    /// Without cached pipelines (here, without even the table) the list asks every server for its
    /// pipelines; a server it cannot reach answers at once with nothing.
    @Test func asksTheServersWhenNothingIsCached() async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        let servers = FakeServerManager(initial: 0)
        _ = servers.add(identifier: "unreachable", serverInfo: with(ServerInfo.fake()) {
            $0.connection.set(address: nil, for: .internal)
            $0.connection.set(address: nil, for: .external)
            $0.connection.set(address: nil, for: .remoteUI)
        })
        Current.servers = servers
        let database = try DatabaseQueue()
        let cacheReads = CacheReadCounter()
        Current.database = {
            cacheReads.increment()
            return database
        }

        let driver = await SwiftUIScreenDriver.show(AssistPipelineAddList { _ in })
        defer { driver.close() }

        // The cache is read once on appear and, because that read fails, the list asks every server. Once they
        // all answered it ends loading and reads the cache again in the same step, so a second read is the
        // fetch round finishing.
        await #expect(driver.waitUntil { cacheReads.value >= 2 })
        await driver.settle()
        // Done loading with nothing cached: only the empty-state row is listed.
        #expect(driver.rows.count == 1)
    }
}

/// Counts reads of `Current.database`; the closure may be called off the main thread.
private final class CacheReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
