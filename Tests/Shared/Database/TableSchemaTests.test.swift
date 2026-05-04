import GRDB
@testable import Shared
import Testing

@Suite("Table Schema Tests")
struct TableSchemaTests {
    /// Helper method to verify table schema
    func verifyTableSchema(
        table: DatabaseTableProtocol,
        expectedTableName: String,
        expectedColumns: [String],
        filterOutId: Bool = false
    ) throws {
        let database = try DatabaseQueue(path: ":memory:")

        // Create the table
        try table.createIfNeeded(database: database)

        // Verify table exists
        let tableExists = try database.read { db in
            try db.tableExists(table.tableName)
        }
        #expect(tableExists, "Table '\(table.tableName)' should exist")

        // Verify table name matches expected
        #expect(table.tableName == expectedTableName, "Table name should be '\(expectedTableName)'")

        // Get actual columns
        let actualColumns = try database.read { db in
            try db.columns(in: table.tableName).map(\.name)
        }

        // Prepare expected columns (handle id filtering)
        var adjustedExpectedColumns = expectedColumns
        if filterOutId {
            adjustedExpectedColumns = expectedColumns.filter { $0 != "id" }
        }

        // Verify column count
        #expect(
            actualColumns.count == adjustedExpectedColumns.count,
            "Table '\(table.tableName)' should have \(adjustedExpectedColumns.count) columns, but has \(actualColumns.count)"
        )

        // Verify all expected columns exist
        for columnName in adjustedExpectedColumns {
            #expect(
                actualColumns.contains(columnName),
                "Table '\(table.tableName)' should contain column '\(columnName)'"
            )
        }
    }

    @Test("HAppEntityTable schema validation")
    func hAppEntityTableSchema() throws {
        let table = HAppEntityTable()
        let expectedColumns = DatabaseTables.AppEntity.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.HAAppEntity.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("WatchConfigTable schema validation")
    func watchConfigTableSchema() throws {
        let table = WatchConfigTable()
        let expectedColumns = DatabaseTables.WatchConfig.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.watchConfig.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("CarPlayConfigTable schema validation")
    func carPlayConfigTableSchema() throws {
        let table = CarPlayConfigTable()
        let expectedColumns = DatabaseTables.CarPlayConfig.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.carPlayConfig.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AppIconShortcutConfigTable schema validation")
    func appIconShortcutConfigTableSchema() throws {
        let table = AppIconShortcutConfigTable()
        let expectedColumns = DatabaseTables.AppIconShortcutConfig.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.appIconShortcutConfig.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("ServerInfoMirrorTable schema validation")
    func serverInfoMirrorTableSchema() throws {
        let table = ServerInfoMirrorTable()
        let expectedColumns = DatabaseTables.ServerInfoMirror.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.serverInfoMirror.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AssistPipelinesTable schema validation")
    func assistPipelinesTableSchema() throws {
        let table = AssistPipelinesTable()
        let expectedColumns = DatabaseTables.AssistPipelines.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.assistPipelines.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AppEntityRegistryListForDisplayTable schema validation")
    func appEntityRegistryListForDisplayTableSchema() throws {
        let table = AppEntityRegistryListForDisplayTable()
        let expectedColumns = DatabaseTables.AppEntityRegistryListForDisplay.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AppEntityRegistryTable schema validation")
    func appEntityRegistryTableSchema() throws {
        let table = AppEntityRegistryTable()
        // Note: AppEntityRegistryTable filters out .id from definedColumns
        let expectedColumns = DatabaseTables.EntityRegistry.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.entityRegistry.rawValue,
            expectedColumns: expectedColumns,
            filterOutId: true
        )
    }

    @Test("AppDeviceRegistryTable schema validation")
    func appDeviceRegistryTableSchema() throws {
        let table = AppDeviceRegistryTable()
        // Note: AppDeviceRegistryTable filters out .id from definedColumns
        let expectedColumns = DatabaseTables.DeviceRegistry.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.deviceRegistry.rawValue,
            expectedColumns: expectedColumns,
            filterOutId: true
        )
    }

    @Test("AppPanelTable schema validation")
    func appPanelTableSchema() throws {
        let table = AppPanelTable()
        let expectedColumns = DatabaseTables.AppPanel.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.appPanel.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("CustomWidgetTable schema validation")
    func customWidgetTableSchema() throws {
        let table = CustomWidgetTable()
        let expectedColumns = DatabaseTables.CustomWidget.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.customWidget.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AppAreaTable schema validation")
    func appAreaTableSchema() throws {
        let table = AppAreaTable()
        let expectedColumns = DatabaseTables.AppArea.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.appArea.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("HomeViewConfigurationTable schema validation")
    func homeViewConfigurationTableSchema() throws {
        let table = HomeViewConfigurationTable()
        let expectedColumns = DatabaseTables.HomeViewConfiguration.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.homeViewConfiguration.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("CameraListConfigurationTable schema validation")
    func cameraListConfigurationTableSchema() throws {
        let table = CameraListConfigurationTable()
        let expectedColumns = DatabaseTables.CameraListConfiguration.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.cameraListConfiguration.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("AssistConfigurationTable schema validation")
    func assistConfigurationTableSchema() throws {
        let table = AssistConfigurationTable()
        let expectedColumns = DatabaseTables.AssistConfiguration.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.assistConfiguration.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("TrustedURLAllowlistTable schema validation")
    func trustedURLAllowlistTableSchema() throws {
        let table = TrustedURLAllowlistTable()
        let expectedColumns = DatabaseTables.TrustedURLAllowlist.allCases.map(\.rawValue)
        try verifyTableSchema(
            table: table,
            expectedTableName: GRDBDatabaseTable.trustedURLAllowlist.rawValue,
            expectedColumns: expectedColumns
        )
    }

    @Test("All 17 tables create successfully together")
    func allTablesCreateTogether() throws {
        let database = try DatabaseQueue(path: ":memory:")
        let tables = DatabaseQueue.tables()

        // Verify we have exactly 17 tables
        #expect(tables.count == 17, "Should have exactly 17 tables, but found \(tables.count)")

        // Create all tables
        for table in tables {
            try table.createIfNeeded(database: database)
        }

        // Verify all tables exist
        let existingTables = try database.read { db in
            try Set(String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'"))
        }

        for table in tables {
            #expect(
                existingTables.contains(table.tableName),
                "Table '\(table.tableName)' should exist in the database"
            )
        }
    }
}
