import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Publishes what its request reads, and nothing when the request fails.
@Suite(.isolatedEnvironment)
@MainActor
struct DatabaseResultsObserverTests {
    private struct Note: FetchableRecord, Decodable, Equatable {
        let body: String
    }

    private struct ReadFailed: Error {}

    private func useDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try database.write { db in
            try db.execute(sql: "CREATE TABLE note (body TEXT); INSERT INTO note VALUES ('hello')")
        }
        Current.database = { database }
        return database
    }

    @Test func publishesTheRequestedRecords() throws {
        _ = try useDatabase()
        let observer = DatabaseResultsObserver<Note> { db in try Note.fetchAll(db, sql: "SELECT * FROM note") }
        #expect(observer.items == [Note(body: "hello")])
    }

    @Test func aFailingRequestPublishesNothing() throws {
        _ = try useDatabase()
        let observer = DatabaseResultsObserver<Note> { _ in throw ReadFailed() }
        #expect(observer.items.isEmpty)
    }
}
