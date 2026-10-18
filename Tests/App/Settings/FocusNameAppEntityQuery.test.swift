import AppIntents
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

// iOS asks this query for the name stored in a Focus Filter every time that Focus activates, and
// reads a name it doesn't get back as one the user deleted — running the filter with no name,
// which is how a Focus *ending* looks. So the only thing these tests really guard is that a
// database the app merely failed to read never comes back as "that name is gone".
// Serialized because every test swaps the process-wide `Current.database` and suspends while the
// query reads it — run in parallel, one test would read another's in-memory queue.
@Suite(.serialized)
struct FocusNameAppEntityQueryTests {
    private let name = FocusName(id: "05D1CF48-9AFD-4B6B-9E70-6F6DDE1B1D3B", name: "Personal")

    /// A database with the table but no rows, or with the row, depending on what is inserted.
    private func makeDatabase(containing names: [FocusName]) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        try FocusNameTable().createIfNeeded(database: queue)
        try queue.write { db in
            for name in names {
                try name.insert(db, onConflict: .replace)
            }
        }
        return queue
    }

    /// Stands in for every way the read can fail in a process iOS has just launched to run the
    /// filter: the query is pointed at a database that has no Focus name table at all.
    private func makeUnreadableDatabase() throws -> DatabaseQueue {
        try DatabaseQueue(path: ":memory:")
    }

    private func withDatabase<T>(_ queue: DatabaseQueue, _ body: () async throws -> T) async rethrows -> T {
        let previous = Current.database
        Current.database = { queue }
        defer { Current.database = previous }
        return try await body()
    }

    @Test func entitiesForIdentifiersReturnsTheStoredName() async throws {
        let queue = try makeDatabase(containing: [name])

        let entities = try await withDatabase(queue) {
            try await FocusNameAppEntityQuery().entities(for: [name.id])
        }

        #expect(entities.map(\.id) == [name.id])
        #expect(entities.map(\.name) == [name.name])
    }

    @Test func entitiesForIdentifiersSkipsANameTheUserDeleted() async throws {
        let queue = try makeDatabase(containing: [])

        let entities = try await withDatabase(queue) {
            try await FocusNameAppEntityQuery().entities(for: [name.id])
        }

        // A readable database that doesn't hold the name is the one case where answering "gone" is
        // right — it is what makes the throwing case below meaningful.
        #expect(entities.isEmpty)
    }

    @Test func entitiesForIdentifiersThrowsWhenTheDatabaseCannotBeRead() async throws {
        let queue = try makeUnreadableDatabase()

        await #expect(throws: (any Error).self) {
            try await withDatabase(queue) {
                try await FocusNameAppEntityQuery().entities(for: [name.id])
            }
        }
    }

    @Test func suggestedEntitiesThrowsWhenTheDatabaseCannotBeRead() async throws {
        let queue = try makeUnreadableDatabase()

        await #expect(throws: (any Error).self) {
            try await withDatabase(queue) {
                try await FocusNameAppEntityQuery().suggestedEntities()
            }
        }
    }

    @Test func entitiesMatchingThrowsWhenTheDatabaseCannotBeRead() async throws {
        let queue = try makeUnreadableDatabase()

        await #expect(throws: (any Error).self) {
            try await withDatabase(queue) {
                try await FocusNameAppEntityQuery().entities(matching: "Per")
            }
        }
    }

    /// The other half of the contract: the settings screen's read stays forgiving, because an empty
    /// list there is a screen with nothing on it rather than an answer iOS acts on.
    @Test func allReportsNoNamesWhenTheDatabaseCannotBeRead() async throws {
        let queue = try makeUnreadableDatabase()

        let names = await withDatabase(queue) { FocusName.all() }

        #expect(names.isEmpty)
    }

    @Test func entitiesMatchingFindsNamesCaseInsensitively() async throws {
        let queue = try makeDatabase(containing: [name])

        let entities = try await withDatabase(queue) {
            try await FocusNameAppEntityQuery().entities(matching: "personal")
        }

        #expect(entities.map(\.name) == [name.name])
    }
}
