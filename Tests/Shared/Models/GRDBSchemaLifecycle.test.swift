import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Schema creation on an existing database (the migration path), obsolete table cleanup and the
/// "delete local data" wipe, each on its own in-memory database. Creating the schema migrates the
/// legacy `allowedTags` preference out of `Current.settingsStore`, so each test gets its own
/// environment and creates the schema against a defaults suite of its own.
@Suite(.isolatedEnvironment)
struct GRDBSchemaLifecycleTests {
    private func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try database.createSchemaWithPrivateDefaults()
        return database
    }

    @Test func creatingTheSchemaAgainMigratesInPlace() throws {
        let database = try makeDatabase()
        try database.createSchemaWithPrivateDefaults()
        let tableNames = DatabaseQueue.tables().map(\.tableName)
        let existing = try database.read { db in try tableNames.filter { try db.tableExists($0) } }
        #expect(existing.count == tableNames.count)
    }

    @Test func obsoleteTablesAreDropped() throws {
        let database = try makeDatabase()
        let obsolete = [GRDBDatabaseTable.clientEvent.rawValue, "entityRegistry"]
        try database.write { db in
            for name in obsolete {
                try db.create(table: name) { $0.column("id", .text) }
            }
        }
        DatabaseQueue.deleteOldTables(database: database)
        let remaining = try database.read { db in try obsolete.filter { try db.tableExists($0) } }
        #expect(remaining.isEmpty)

        // A steady-state database has nothing to drop.
        DatabaseQueue.deleteOldTables(database: database)
    }

    @Test func eraseAllDataEmptiesEveryTable() throws {
        let database = try makeDatabase()
        try database.write { db in
            try NotificationSnoozeAction(minutes: 5, sortOrder: 0).insert(db)
            try WatchComplication(identifier: "c").insert(db)
        }
        try database.eraseAllData()
        let counts = try database.read { db in
            try (NotificationSnoozeAction.fetchCount(db), WatchComplication.fetchCount(db))
        }
        #expect(counts.0 == 0)
        #expect(counts.1 == 0)
        #expect(DatabaseQueue.databasePath().hasSuffix("test_database.sqlite"))
    }
}
