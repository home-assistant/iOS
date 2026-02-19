import GRDB
@testable import Shared
import Testing

@Suite("Database Migration Tests")
struct DatabaseMigrationTests {
    /// Helper table class for migration testing
    class TestTable: DatabaseTableProtocol {
        var tableName: String
        var definedColumns: [String]

        init(tableName: String, definedColumns: [String]) {
            self.tableName = tableName
            self.definedColumns = definedColumns
        }

        func createIfNeeded(database: DatabaseQueue) throws {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(tableName)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: tableName) { t in
                        // Create all defined columns
                        for columnName in definedColumns {
                            t.column(columnName, .text)
                        }
                    }
                }
            } else {
                try migrateColumns(database: database)
            }
        }
    }

    @Test("Add new columns to existing table")
    func testAddNewColumns() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create initial table with 2 columns
        let initialTable = TestTable(tableName: "testTable", definedColumns: ["column1", "column2"])
        try initialTable.createIfNeeded(database: database)

        // Verify initial columns
        var columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 2)
        #expect(columns.contains("column1"))
        #expect(columns.contains("column2"))

        // Create updated table definition with 3 columns (added column3)
        let updatedTable = TestTable(tableName: "testTable", definedColumns: ["column1", "column2", "column3"])
        try updatedTable.createIfNeeded(database: database)

        // Verify column was added
        columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 3, "Should have 3 columns after adding column3")
        #expect(columns.contains("column1"))
        #expect(columns.contains("column2"))
        #expect(columns.contains("column3"))
    }

    @Test("Skip already existing columns")
    func testSkipExistingColumns() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create table with 2 columns
        let table = TestTable(tableName: "testTable", definedColumns: ["column1", "column2"])
        try table.createIfNeeded(database: database)

        // Try to create the same table again (should skip since columns already exist)
        try table.createIfNeeded(database: database)

        // Verify still only 2 columns
        let columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 2)
        #expect(columns.contains("column1"))
        #expect(columns.contains("column2"))
    }

    @Test("Remove obsolete columns")
    func testRemoveObsoleteColumns() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create initial table with 3 columns
        let initialTable = TestTable(
            tableName: "testTable",
            definedColumns: ["column1", "column2", "obsoleteColumn"]
        )
        try initialTable.createIfNeeded(database: database)

        // Verify initial columns
        var columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 3)
        #expect(columns.contains("obsoleteColumn"))

        // Create updated table definition without obsoleteColumn
        let updatedTable = TestTable(tableName: "testTable", definedColumns: ["column1", "column2"])
        try updatedTable.createIfNeeded(database: database)

        // Verify obsolete column was removed
        columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 2, "Should have 2 columns after removing obsoleteColumn")
        #expect(columns.contains("column1"))
        #expect(columns.contains("column2"))
        #expect(!columns.contains("obsoleteColumn"), "obsoleteColumn should have been removed")
    }

    @Test("Handle add and remove simultaneously")
    func testAddAndRemoveSimultaneously() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create initial table with columns: column1, column2, obsoleteColumn
        let initialTable = TestTable(
            tableName: "testTable",
            definedColumns: ["column1", "column2", "obsoleteColumn"]
        )
        try initialTable.createIfNeeded(database: database)

        // Create updated table definition: column1, column2, newColumn (removed obsoleteColumn, added newColumn)
        let updatedTable = TestTable(tableName: "testTable", definedColumns: ["column1", "column2", "newColumn"])
        try updatedTable.createIfNeeded(database: database)

        // Verify columns
        let columns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(columns.count == 3, "Should have 3 columns")
        #expect(columns.contains("column1"))
        #expect(columns.contains("column2"))
        #expect(columns.contains("newColumn"), "newColumn should have been added")
        #expect(!columns.contains("obsoleteColumn"), "obsoleteColumn should have been removed")
    }

    @Test("Handle no changes needed")
    func testNoChangesNeeded() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create table with 2 columns
        let table = TestTable(tableName: "testTable", definedColumns: ["column1", "column2"])
        try table.createIfNeeded(database: database)

        // Get initial columns
        let initialColumns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }

        // Run migration again with same columns
        try table.createIfNeeded(database: database)

        // Verify columns haven't changed
        let finalColumns = try database.read { db in
            try db.columns(in: "testTable").map(\.name)
        }
        #expect(initialColumns == finalColumns, "Columns should remain unchanged")
    }

    @Test("Migration with actual table: HAppEntityTable")
    func testRealTableMigration() throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create HAppEntityTable
        let table = HAppEntityTable()
        try table.createIfNeeded(database: database)

        // Verify table was created
        let tableExists = try database.read { db in
            try db.tableExists(table.tableName)
        }
        #expect(tableExists)

        // Call createIfNeeded again (should trigger migration path, not creation)
        try table.createIfNeeded(database: database)

        // Verify table still exists and has correct columns
        let columns = try database.read { db in
            try db.columns(in: table.tableName).map(\.name)
        }
        let expectedColumns = DatabaseTables.AppEntity.allCases.map(\.rawValue)
        #expect(Set(columns) == Set(expectedColumns))
    }
}
