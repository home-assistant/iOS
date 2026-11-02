import GRDB
@testable import Shared

/// An in-memory database with every app table, for tests that read or write the CarPlay config,
/// cached entities, areas or the entity registry through `Current.database`.
enum CarPlayTestDatabase {
    static func make() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    /// A database with no tables at all: every read throws, which is how the catch paths run.
    static func broken() throws -> DatabaseQueue {
        try DatabaseQueue(path: ":memory:")
    }
}
