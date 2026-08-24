@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct AppMigrationChunkStoreTests {
    init() {
        AppMigrationChunkStore.clear()
    }

    /// The common case: everything fits in one link, so it assembles without a single round trip.
    @Test func assemblesASingleChunkImmediately() {
        defer { AppMigrationChunkStore.clear() }

        let assembled = AppMigrationChunkStore
            .accept(.init(sessionID: "s", index: 0, total: 1, data: "everything"))

        #expect(assembled == "everything")
    }

    @Test func withholdsUntilEveryChunkHasArrived() {
        defer { AppMigrationChunkStore.clear() }

        #expect(AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 3, data: "a")) == nil)
        #expect(AppMigrationChunkStore.accept(.init(sessionID: "s", index: 1, total: 3, data: "b")) == nil)
        #expect(AppMigrationChunkStore.accept(.init(sessionID: "s", index: 2, total: 3, data: "c")) == "abc")
    }

    /// Round trips can be retried, so slices may arrive out of order; they are reassembled by index
    /// rather than by arrival.
    @Test func assemblesInIndexOrderNotArrivalOrder() {
        defer { AppMigrationChunkStore.clear() }

        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 2, total: 3, data: "c"))
        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 3, data: "a"))
        let assembled = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 1, total: 3, data: "b"))

        #expect(assembled == "abc")
    }

    /// A duplicate must not count towards completion, or a payload would be assembled with a hole.
    @Test func treatsARepeatedChunkAsTheSameSlice() {
        defer { AppMigrationChunkStore.clear() }

        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 2, data: "a"))
        #expect(AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 2, data: "a")) == nil)
        #expect(AppMigrationChunkStore.accept(.init(sessionID: "s", index: 1, total: 2, data: "b")) == "ab")
    }

    /// An abandoned attempt must never contribute slices to a later one.
    @Test func discardsChunksFromAnEarlierSession() {
        defer { AppMigrationChunkStore.clear() }

        _ = AppMigrationChunkStore.accept(.init(sessionID: "old", index: 0, total: 2, data: "stale"))

        #expect(AppMigrationChunkStore.accept(.init(sessionID: "new", index: 0, total: 2, data: "a")) == nil)
        #expect(AppMigrationChunkStore.receivedIndices(forSession: "old").isEmpty)
        #expect(AppMigrationChunkStore.accept(.init(sessionID: "new", index: 1, total: 2, data: "b")) == "ab")
    }

    /// What the receiving app asks for next is derived from this, so it has to report exactly the
    /// slices it holds — and nothing for a session it does not.
    @Test func reportsWhichChunksItHolds() {
        defer { AppMigrationChunkStore.clear() }

        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 4, data: "a"))
        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 2, total: 4, data: "c"))

        #expect(AppMigrationChunkStore.receivedIndices(forSession: "s") == [0, 2])
        #expect(AppMigrationChunkStore.receivedIndices(forSession: "other").isEmpty)
    }

    @Test func clearsOnceAssembled() {
        defer { AppMigrationChunkStore.clear() }

        _ = AppMigrationChunkStore.accept(.init(sessionID: "s", index: 0, total: 1, data: "a"))

        #expect(AppMigrationChunkStore.receivedIndices(forSession: "s").isEmpty)
    }
}
