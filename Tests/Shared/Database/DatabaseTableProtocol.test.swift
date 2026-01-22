import Testing
import GRDB
@testable import Shared

@Suite("Database Table Protocol Tests")
struct DatabaseTableProtocolTests {
    @Test("HAppEntityTable conforms to DatabaseTableProtocol")
    func testHAppEntityTableConformance() throws {
        let table = HAppEntityTable()
        #expect(table.tableName == GRDBDatabaseTable.HAAppEntity.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        // Verify definedColumns match DatabaseTables enum
        let expectedColumns = DatabaseTables.AppEntity.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("WatchConfigTable conforms to DatabaseTableProtocol")
    func testWatchConfigTableConformance() throws {
        let table = WatchConfigTable()
        #expect(table.tableName == GRDBDatabaseTable.watchConfig.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.WatchConfig.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("CarPlayConfigTable conforms to DatabaseTableProtocol")
    func testCarPlayConfigTableConformance() throws {
        let table = CarPlayConfigTable()
        #expect(table.tableName == GRDBDatabaseTable.carPlayConfig.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.CarPlayConfig.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("AssistPipelinesTable conforms to DatabaseTableProtocol")
    func testAssistPipelinesTableConformance() throws {
        let table = AssistPipelinesTable()
        #expect(table.tableName == GRDBDatabaseTable.assistPipelines.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.AssistPipelines.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("AppEntityRegistryListForDisplayTable conforms to DatabaseTableProtocol")
    func testAppEntityRegistryListForDisplayTableConformance() throws {
        let table = AppEntityRegistryListForDisplayTable()
        #expect(table.tableName == GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.AppEntityRegistryListForDisplay.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("AppEntityRegistryTable conforms to DatabaseTableProtocol")
    func testAppEntityRegistryTableConformance() throws {
        let table = AppEntityRegistryTable()
        #expect(table.tableName == GRDBDatabaseTable.entityRegistry.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        // Note: AppEntityRegistryTable filters out .id from definedColumns
        let expectedColumns = DatabaseTables.EntityRegistry.allCases
            .filter { $0 != .id }
            .map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
        #expect(!table.definedColumns.contains("id"), "definedColumns should not contain 'id'")
    }

    @Test("AppDeviceRegistryTable conforms to DatabaseTableProtocol")
    func testAppDeviceRegistryTableConformance() throws {
        let table = AppDeviceRegistryTable()
        #expect(table.tableName == GRDBDatabaseTable.deviceRegistry.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        // Note: AppDeviceRegistryTable filters out .id from definedColumns
        let expectedColumns = DatabaseTables.DeviceRegistry.allCases
            .filter { $0 != .id }
            .map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
        #expect(!table.definedColumns.contains("id"), "definedColumns should not contain 'id'")
    }

    @Test("AppPanelTable conforms to DatabaseTableProtocol")
    func testAppPanelTableConformance() throws {
        let table = AppPanelTable()
        #expect(table.tableName == GRDBDatabaseTable.appPanel.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.AppPanel.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("CustomWidgetTable conforms to DatabaseTableProtocol")
    func testCustomWidgetTableConformance() throws {
        let table = CustomWidgetTable()
        #expect(table.tableName == GRDBDatabaseTable.customWidget.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.CustomWidget.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("AppAreaTable conforms to DatabaseTableProtocol")
    func testAppAreaTableConformance() throws {
        let table = AppAreaTable()
        #expect(table.tableName == GRDBDatabaseTable.appArea.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.AppArea.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("HomeViewConfigurationTable conforms to DatabaseTableProtocol")
    func testHomeViewConfigurationTableConformance() throws {
        let table = HomeViewConfigurationTable()
        #expect(table.tableName == GRDBDatabaseTable.homeViewConfiguration.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.HomeViewConfiguration.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("CameraListConfigurationTable conforms to DatabaseTableProtocol")
    func testCameraListConfigurationTableConformance() throws {
        let table = CameraListConfigurationTable()
        #expect(table.tableName == GRDBDatabaseTable.cameraListConfiguration.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.CameraListConfiguration.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("AssistConfigurationTable conforms to DatabaseTableProtocol")
    func testAssistConfigurationTableConformance() throws {
        let table = AssistConfigurationTable()
        #expect(table.tableName == GRDBDatabaseTable.assistConfiguration.rawValue)
        #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty")

        let expectedColumns = DatabaseTables.AssistConfiguration.allCases.map(\.rawValue)
        #expect(Set(table.definedColumns) == Set(expectedColumns))
    }

    @Test("All 13 tables conform to DatabaseTableProtocol")
    func testAllTablesConformToProtocol() throws {
        let tables = DatabaseQueue.tables()
        #expect(tables.count == 13, "Should have exactly 13 tables")

        for table in tables {
            // Verify each table has a non-empty tableName
            #expect(!table.tableName.isEmpty, "Table name should not be empty")

            // Verify each table has at least one defined column
            #expect(!table.definedColumns.isEmpty, "definedColumns should not be empty for \(table.tableName)")
        }
    }
}
