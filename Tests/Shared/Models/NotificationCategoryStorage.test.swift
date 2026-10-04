import Foundation
import GRDB
@testable import Shared
import XCTest

final class NotificationCategoryStorageTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUp() {
        super.setUp()
        previousDatabase = Current.database
    }

    override func tearDown() {
        Current.database = previousDatabase
        super.tearDown()
    }

    func testQueriesWithoutTableFailGracefully() throws {
        let database = try DatabaseQueue()
        Current.database = { database }

        NotificationCategory(identifier: "MISSING").save()
        NotificationCategory.delete(identifiers: ["MISSING"])

        XCTAssertTrue(NotificationCategory.all().isEmpty)
        XCTAssertNil(NotificationCategory.fetch(identifier: "MISSING"))
    }

    func testDeleteWithoutIdentifiersKeepsEverything() throws {
        let database = try DatabaseQueue()
        try NotificationCategoryTable().createIfNeeded(database: database)
        Current.database = { database }

        NotificationCategory(identifier: "KEEP").save()
        NotificationCategory.delete(identifiers: [])

        XCTAssertEqual(NotificationCategory.all().map(\.identifier), ["KEEP"])
        XCTAssertNil(NotificationCategory.fetch(identifier: "OTHER"))
    }

    func testCreateIfNeededOnExistingTableKeepsRows() throws {
        let database = try DatabaseQueue()
        let table = NotificationCategoryTable()
        try table.createIfNeeded(database: database)
        Current.database = { database }

        NotificationCategory(identifier: "EXISTING", name: "Existing").save()

        try table.createIfNeeded(database: database)

        XCTAssertEqual(NotificationCategory.fetch(identifier: "EXISTING")?.name, "Existing")
        XCTAssertEqual(table.tableName, NotificationCategory.databaseTableName)
        XCTAssertEqual(
            Set(table.definedColumns),
            Set(DatabaseTables.NotificationCategory.allCases.map(\.rawValue))
        )
    }

    func testUpdatableModelConfiguration() {
        XCTAssertEqual(
            NotificationCategory.serverIdentifierColumnName,
            DatabaseTables.NotificationCategory.serverIdentifier.rawValue
        )
        XCTAssertEqual(
            NotificationCategory.primaryKeyColumnName,
            DatabaseTables.NotificationCategory.identifier.rawValue
        )
        XCTAssertNotNil(NotificationCategory.updateEligibleCondition)
        XCTAssertEqual(NotificationCategory.primaryKey(sourceIdentifier: "alarm", serverIdentifier: "s1"), "ALARM")

        let category = NotificationCategory(primaryKey: "ALARM", serverIdentifier: "s1")
        XCTAssertEqual(category.identifier, "ALARM")
        XCTAssertEqual(category.id, "ALARM")
        XCTAssertEqual(category.primaryKeyValue, "ALARM")
        XCTAssertEqual(category.serverIdentifier, "s1")
        XCTAssertFalse(category.isServerControlled)
        XCTAssertTrue(category.actions.isEmpty)
    }
}
