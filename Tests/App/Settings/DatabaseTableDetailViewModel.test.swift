import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The database explorer reads whichever table the user picked straight from SQLite, so these run
/// it against a scratch in-memory database holding a table built for the purpose.
@MainActor
@Suite(.serialized)
struct DatabaseTableDetailViewModelTests {
    private static let tableName = "explorerSample"

    @Test func loadingReadsEveryRowAndNotesTheServerColumn() throws {
        try withSampleDatabase {
            let viewModel = DatabaseTableDetailViewModel(tableName: Self.tableName)
            viewModel.loadData()

            #expect(viewModel.hasServerIdColumn)
            #expect(viewModel.rows.count == 3)
            #expect(viewModel.filteredRows.count == 3)

            let kitchen = try #require(viewModel.rows.first(where: { $0["id"] == "1" }))
            #expect(kitchen["name"] == "Kitchen")
            #expect(kitchen["serverId"] == "server-a")
            #expect(kitchen["note"] == "nil")
        }
    }

    @Test func filteringByServerKeepsOnlyThatServersRows() throws {
        try withSampleDatabase {
            let viewModel = DatabaseTableDetailViewModel(tableName: Self.tableName)
            viewModel.loadData()

            viewModel.selectedServerId = "server-b"

            #expect(viewModel.filteredRows.map { $0["name"] } == ["Office"])
        }
    }

    @Test func searchingMatchesAnyValueIgnoringCase() throws {
        try withSampleDatabase {
            let viewModel = DatabaseTableDetailViewModel(tableName: Self.tableName)
            viewModel.loadData()

            viewModel.searchText = "GARDEN"
            #expect(viewModel.filteredRows.map { $0["id"] } == ["3"])

            viewModel.selectedServerId = "server-b"
            #expect(viewModel.filteredRows.isEmpty)
        }
    }

    @Test func aServerFilterIsIgnoredForTablesWithoutAServerColumn() throws {
        try withSampleDatabase {
            let viewModel = DatabaseTableDetailViewModel(tableName: "explorerPlain")
            viewModel.loadData()

            #expect(viewModel.hasServerIdColumn == false)
            viewModel.selectedServerId = "server-a"
            #expect(viewModel.filteredRows.count == 1)
        }
    }

    @Test func anUnknownTableLoadsNothing() throws {
        try withSampleDatabase {
            let viewModel = DatabaseTableDetailViewModel(tableName: "doesNotExist\"; DROP TABLE explorerSample; --")
            viewModel.loadData()

            #expect(viewModel.rows.isEmpty)
            #expect(viewModel.hasServerIdColumn == false)

            let stillThere = DatabaseTableDetailViewModel(tableName: Self.tableName)
            stillThere.loadData()
            #expect(stillThere.rows.count == 3)
        }
    }

    @Test func screensRenderTheTablesAndTheirRows() throws {
        try withSampleDatabase {
            render(DatabaseExplorerView())
            render(DatabaseTableDetailView(tableName: Self.tableName))
            render(DatabaseTableDetailView(tableName: "explorerEmpty"))
            render(DatabaseRowDetailView(row: [
                "id": "1",
                "serverId": "server-a",
                "name": "Kitchen",
                "zeta": "last",
                "alpha": "first",
            ]))
        }
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withSampleDatabase(_ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        // Two servers, so the detail screen offers its server filter.
        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: "server-a"), serverInfo: .fake())
        servers.add(identifier: .init(rawValue: "server-b"), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        try database.write { db in
            try db.execute(sql: """
            CREATE TABLE explorerSample (id TEXT, serverId TEXT, name TEXT, area TEXT, note TEXT, size INTEGER);
            INSERT INTO explorerSample VALUES ('1', 'server-a', 'Kitchen', 'Ground floor', NULL, 4);
            INSERT INTO explorerSample VALUES ('2', 'server-b', 'Office', 'First floor', 'desk', 2);
            INSERT INTO explorerSample VALUES ('3', 'server-a', 'Garden', 'Outside', 'lawn', 9);
            CREATE TABLE explorerPlain (id TEXT, value TEXT);
            INSERT INTO explorerPlain VALUES ('only', 'row');
            CREATE TABLE explorerEmpty (id TEXT);
            """)
        }
        Current.database = { database }

        try body()
    }
}
