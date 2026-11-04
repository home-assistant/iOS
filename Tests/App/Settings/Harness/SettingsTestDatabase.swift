import GRDB
@testable import Shared

/// An in-memory app database with every table the app creates, for tests that point `Current.database`
/// at their own data. Callers swap `Current.database`, so their suite carries `.sharedState`.
enum SettingsTestDatabase {
    static func make() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    /// Runs `body` with `Current.database` pointing at a fresh in-memory database, then restores it.
    static func with<T>(
        _ seed: (Database) throws -> Void = { _ in },
        _ body: (DatabaseQueue) async throws -> T
    ) async throws -> T {
        let previous = Current.database
        let database = try make()
        try await database.write { db in try seed(db) }
        Current.database = { database }
        defer { Current.database = previous }
        return try await body(database)
    }

    /// Runs `body` with `Current.database` pointing at an in-memory database without a single table,
    /// so every read and write of the app's records throws, then restores it.
    static func withoutTables<T>(_ body: (DatabaseQueue) async throws -> T) async throws -> T {
        let previous = Current.database
        let database = try DatabaseQueue()
        Current.database = { database }
        defer { Current.database = previous }
        return try await body(database)
    }

    /// Runs `body` with `Current.database` pointing at a closed database, so every access throws, even
    /// the ones that only read `sqlite_master`; then restores it.
    static func closed<T>(_ body: () async throws -> T) async throws -> T {
        let previous = Current.database
        let database = try DatabaseQueue()
        try database.close()
        Current.database = { database }
        defer { Current.database = previous }
        return try await body()
    }
}
