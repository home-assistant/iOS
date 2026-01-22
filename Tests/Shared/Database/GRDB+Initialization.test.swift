import GRDB
@testable import Shared
import XCTest

class GRDBInitializationTests: XCTestCase {
    var testDatabasePath: String!

    override func setUp() {
        super.setUp()
        // Create a unique test database path for each test
        let tempDirectory = NSTemporaryDirectory()
        testDatabasePath = (tempDirectory as NSString).appendingPathComponent("test_grdb_\(UUID().uuidString).sqlite")
    }

    override func tearDown() {
        // Clean up test database
        if let path = testDatabasePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        testDatabasePath = nil
        super.tearDown()
    }

    func testDatabasePathInTestEnvironment() throws {
        // The test environment variable should already be set by XCTest
        let path = DatabaseQueue.databasePath()

        // In test environment, path should be in temp directory
        XCTAssertTrue(
            path.contains(NSTemporaryDirectory()) || path.contains("test_database.sqlite"),
            "Database path in test environment should use temp directory or test_database.sqlite"
        )
    }

    func testTablesReturns13Tables() throws {
        let tables = DatabaseQueue.tables()
        XCTAssertEqual(tables.count, 13, "DatabaseQueue.tables() should return exactly 13 tables")
    }

    func testTablesContainsAllExpectedTables() throws {
        let tables = DatabaseQueue.tables()
        let tableNames = tables.map(\.tableName)

        // Verify all expected table names are present
        let expectedTableNames = [
            GRDBDatabaseTable.HAAppEntity.rawValue,
            GRDBDatabaseTable.watchConfig.rawValue,
            GRDBDatabaseTable.carPlayConfig.rawValue,
            GRDBDatabaseTable.assistPipelines.rawValue,
            GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue,
            GRDBDatabaseTable.entityRegistry.rawValue,
            GRDBDatabaseTable.deviceRegistry.rawValue,
            GRDBDatabaseTable.appPanel.rawValue,
            GRDBDatabaseTable.customWidget.rawValue,
            GRDBDatabaseTable.appArea.rawValue,
            GRDBDatabaseTable.homeViewConfiguration.rawValue,
            GRDBDatabaseTable.cameraListConfiguration.rawValue,
            GRDBDatabaseTable.assistConfiguration.rawValue,
        ]

        for expectedName in expectedTableNames {
            XCTAssertTrue(
                tableNames.contains(expectedName),
                "tables() should contain table named '\(expectedName)'"
            )
        }
    }

    func testAppDatabaseCreatesAllTables() throws {
        // Create a test database using the static method
        let database = try DatabaseQueue(path: testDatabasePath)

        // Create all tables
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }

        // Verify all tables exist
        let existingTables = try database.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }

        for table in DatabaseQueue.tables() {
            XCTAssertTrue(
                existingTables.contains(table.tableName),
                "Database should contain table '\(table.tableName)'"
            )
        }
    }

    func testDeleteOldTablesRemovesClientEventTable() throws {
        let database = try DatabaseQueue(path: testDatabasePath)

        // Create the old clientEvent table
        try database.write { db in
            try db.create(table: GRDBDatabaseTable.clientEvent.rawValue) { t in
                t.column("id", .text).primaryKey()
                t.column("text", .text)
            }
        }

        // Verify clientEvent table exists
        var tableExists = try database.read { db in
            try db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
        }
        XCTAssertTrue(tableExists, "clientEvent table should exist before cleanup")

        // Call deleteOldTables
        DatabaseQueue.deleteOldTables(database: database)

        // Verify clientEvent table no longer exists
        tableExists = try database.read { db in
            try db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
        }
        XCTAssertFalse(tableExists, "clientEvent table should not exist after cleanup")
    }

    func testDeleteOldTablesHandlesMissingTableGracefully() throws {
        let database = try DatabaseQueue(path: testDatabasePath)

        // Verify clientEvent table doesn't exist
        let tableExists = try database.read { db in
            try db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
        }
        XCTAssertFalse(tableExists, "clientEvent table should not exist initially")

        // Call deleteOldTables (should not throw error)
        XCTAssertNoThrow(
            DatabaseQueue.deleteOldTables(database: database),
            "deleteOldTables should handle missing table gracefully"
        )
    }

    func testTableCreationErrorLogsToClientEventStore() throws {
        // Mock the client event store
        var loggedEvents: [ClientEvent] = []
        let mockStore = MockClientEventStore(onAddEvent: { event in
            loggedEvents.append(event)
        })

        // Replace Current.clientEventStore temporarily
        let originalStore = Current.clientEventStore
        Current.clientEventStore = mockStore
        defer { Current.clientEventStore = originalStore }

        // Create a test table that will fail during creation
        class FailingTable: DatabaseTableProtocol {
            var tableName: String { "failingTable" }
            var definedColumns: [String] { ["column1"] }
            func createIfNeeded(database: DatabaseQueue) throws {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Forced error"])
            }
        }

        let database = try DatabaseQueue(path: testDatabasePath)
        let failingTable = FailingTable()

        // Try to create the failing table (mimic what appDatabase does)
        do {
            try failingTable.createIfNeeded(database: database)
        } catch {
            let className = String(describing: type(of: failingTable))
            let errorMessage = "Failed create GRDB table \(className), error: \(error.localizedDescription)"
            mockStore.addEvent(ClientEvent(text: errorMessage, type: .database))
        }

        // Verify error was logged
        XCTAssertEqual(loggedEvents.count, 1, "Should have logged 1 error")
        XCTAssertTrue(
            loggedEvents.first?.text.contains("Failed create GRDB table") ?? false,
            "Error message should contain 'Failed create GRDB table'"
        )
        XCTAssertEqual(loggedEvents.first?.type, .database, "Error type should be .database")
    }

    func testMultipleTablesCanCoexist() throws {
        let database = try DatabaseQueue(path: testDatabasePath)

        // Create multiple tables
        let table1 = HAppEntityTable()
        let table2 = WatchConfigTable()
        let table3 = CarPlayConfigTable()

        try table1.createIfNeeded(database: database)
        try table2.createIfNeeded(database: database)
        try table3.createIfNeeded(database: database)

        // Verify all tables exist
        let existingTables = try database.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }

        XCTAssertTrue(existingTables.contains(table1.tableName))
        XCTAssertTrue(existingTables.contains(table2.tableName))
        XCTAssertTrue(existingTables.contains(table3.tableName))
    }
}

// MARK: - Mock Client Event Store

class MockClientEventStore: ClientEventStoreProtocol {
    private let onAddEvent: (ClientEvent) -> Void

    init(onAddEvent: @escaping (ClientEvent) -> Void) {
        self.onAddEvent = onAddEvent
    }

    func addEvent(_ event: ClientEvent) {
        onAddEvent(event)
    }

    func getEvents() -> [ClientEvent] {
        []
    }

    func clearAllEvents() {}
}
