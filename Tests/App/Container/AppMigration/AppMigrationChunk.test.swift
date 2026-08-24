@testable import HomeAssistant
@testable import Shared
import Testing

struct AppMigrationChunkTests {
    @Test func roundTripsThroughItsWireFormat() {
        let chunk = AppMigrationChunk(sessionID: "ABC-123", index: 2, total: 5, data: "payload-data")

        let decoded = AppMigrationChunk(encoded: chunk.encoded)

        #expect(decoded == chunk)
    }

    /// The header is split off with a bounded number of splits, so a payload that happens to contain
    /// the separator still survives intact.
    @Test func keepsDataContainingSeparators() {
        let chunk = AppMigrationChunk(sessionID: "s", index: 0, total: 1, data: "a.b.c.d.e")

        #expect(AppMigrationChunk(encoded: chunk.encoded)?.data == "a.b.c.d.e")
    }

    @Test func marksOnlyTheFinalChunkAsLast() {
        #expect(AppMigrationChunk(sessionID: "s", index: 0, total: 3, data: "d").isLast == false)
        #expect(AppMigrationChunk(sessionID: "s", index: 2, total: 3, data: "d").isLast)
        #expect(AppMigrationChunk(sessionID: "s", index: 0, total: 1, data: "d").isLast)
    }

    @Test(arguments: [
        "2.session.0.1.data", // version this build does not know
        "1.session.0.1", // truncated
        "1.session.x.1.data", // non-numeric index
        "1.session.1.1.data", // index outside total
        "1.session.0.0.data", // no chunks at all
        "1..0.1.data", // no session
        "1.session.0.1.", // no payload
        "",
    ]) func rejectsMalformedInput(_ encoded: String) {
        #expect(AppMigrationChunk(encoded: encoded) == nil)
    }
}
