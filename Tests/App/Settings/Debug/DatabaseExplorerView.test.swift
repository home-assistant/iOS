import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Points `Current.database` at an in-memory database with one table that has a `serverId` column and
/// one that doesn't, then browses it through the database explorer and checks the table view model's
/// filtering.
///
/// `.sharedState`: the test swaps `Current.database` and `Current.servers`, which the screens read on
/// the main queue.
@Suite(.sharedState)
@MainActor
struct DatabaseExplorerViewTests {
    private func withDatabase(_ body: (DatabaseQueue, [Server]) async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 2)
        let database = try DatabaseQueue()
        try await database.write { db in
            try db.execute(sql: """
            CREATE TABLE widgets (id TEXT, serverId TEXT, name TEXT, color TEXT, size INTEGER, note TEXT);
            CREATE TABLE notes (body TEXT);
            """)
            let servers = manager.all.map(\.identifier.rawValue)
            try db.execute(
                sql: "INSERT INTO widgets VALUES ('w1', ?, 'Lamp', 'red', 3, NULL)",
                arguments: [servers[0]]
            )
            try db.execute(
                sql: "INSERT INTO widgets VALUES ('w2', ?, 'Fan', 'blue', 5, 'quiet')",
                arguments: [servers[1]]
            )
            try db.execute(sql: "INSERT INTO notes VALUES ('hello')")
        }
        Current.database = { database }
        Current.servers = manager
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        try await body(database, manager.all)
    }

    @Test func viewModelFiltersByServerAndSearchText() async throws {
        try await withDatabase { _, servers in
            let viewModel = DatabaseTableDetailViewModel(tableName: "widgets")
            viewModel.loadData()
            #expect(viewModel.hasServerIdColumn)
            #expect(viewModel.rows.count == 2)
            #expect(viewModel.rows.contains { $0["note"] == "nil" })

            viewModel.selectedServerId = servers[1].identifier.rawValue
            #expect(viewModel.filteredRows.map { $0["id"] } == ["w2"])

            viewModel.selectedServerId = nil
            viewModel.searchText = "LAMP"
            #expect(viewModel.filteredRows.map { $0["id"] } == ["w1"])

            viewModel.searchText = "nothing matches"
            #expect(viewModel.filteredRows.isEmpty)
        }
    }

    @Test func viewModelIgnoresTablesThatDoNotExist() async throws {
        try await withDatabase { _, _ in
            let viewModel = DatabaseTableDetailViewModel(tableName: "missing\"; DROP TABLE widgets; --")
            viewModel.loadData()
            #expect(viewModel.rows.isEmpty)
            #expect(!viewModel.hasServerIdColumn)

            let notes = DatabaseTableDetailViewModel(tableName: "notes")
            notes.loadData()
            #expect(!notes.hasServerIdColumn)
            #expect(notes.rows == [["body": "hello"]])
            // Without a serverId column a selected server filters nothing out.
            notes.selectedServerId = "anything"
            #expect(notes.filteredRows.count == 1)
        }
    }

    /// A database that cannot be read lists no tables and no rows.
    @Test func aClosedDatabaseShowsNothing() async throws {
        try await SettingsTestDatabase.closed {
            let viewModel = DatabaseTableDetailViewModel(tableName: "widgets")
            viewModel.loadData()
            #expect(viewModel.rows.isEmpty)

            let driver = await SwiftUIScreenDriver.show(DatabaseExplorerView())
            defer { driver.close() }
            #expect(driver.rows.isEmpty)
        }
    }

    @Test func browsesTablesRowsAndRowDetails() async throws {
        try await withDatabase { _, _ in
            let harness = await SettingsScreenHarness.show(DatabaseExplorerView())
            await #expect(harness.waitUntil { harness.rows.count == 2 })

            // "notes" sorts first, then "widgets".
            if await harness.push(IndexPath(item: 0, section: 0)) {
                await harness.pop()
            }
            await #expect(harness.push(IndexPath(item: 1, section: 0)))
            await #expect(harness.waitUntil { harness.rows.count >= 3 })

            // The server pills come first; open each widget row.
            for row in harness.rows.dropFirst() {
                if await harness.push(row) {
                    await harness.pop()
                }
            }
            await harness.search("no such widget")
            await harness.search("")
            await harness.close()
        }
    }

    @Test func showsTheEmptyStateForAnEmptyTable() async throws {
        try await withDatabase { database, _ in
            try await database.write { db in try db.execute(sql: "DELETE FROM notes") }
            let harness = await SettingsScreenHarness.show(DatabaseTableDetailView(tableName: "notes"))
            #expect(harness.rows.count == 1)
            await harness.close()
        }
    }
}
