@testable import Shared
import XCTest

class ServerManagerMirrorWriteSequencerTests: XCTestCase {
    private var sequencer: ServerManagerMirrorWriteSequencer!

    override func setUp() {
        super.setUp()
        sequencer = .init()
    }

    func testTicketsAreIncreasing() {
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        XCTAssertLessThan(first, second)
    }

    func testWritesInTicketOrderBothRun() {
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        var written = [String]()

        XCTAssertTrue(sequencer.apply(first, key: "server") { written.append("first") })
        XCTAssertTrue(sequencer.apply(second, key: "server") { written.append("second") })
        XCTAssertEqual(written, ["first", "second"])
    }

    func testReversedWriteOrderKeepsTheLaterSave() {
        // Two saves of one server commit as first then second under the cache lock, but reach the
        // mirror the other way round: the older save must not overwrite the newer one.
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        var written = [String]()

        XCTAssertTrue(sequencer.apply(second, key: "server") { written.append("second") })
        XCTAssertFalse(sequencer.apply(first, key: "server") { written.append("first") })
        XCTAssertEqual(written, ["second"])
    }

    func testSameTicketIsNotAppliedTwice() {
        let ticket = sequencer.ticket()
        var count = 0

        XCTAssertTrue(sequencer.apply(ticket, key: "server") { count += 1 })
        XCTAssertFalse(sequencer.apply(ticket, key: "server") { count += 1 })
        XCTAssertEqual(count, 1)
    }

    func testOrderIsTrackedPerKey() {
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        var written = [String]()

        XCTAssertTrue(sequencer.apply(second, key: "a") { written.append("a2") })
        XCTAssertTrue(sequencer.apply(first, key: "b") { written.append("b1") })
        XCTAssertEqual(written, ["a2", "b1"])
    }

    func testClearSupersedesEarlierWrites() {
        let write = sequencer.ticket()
        let clear = sequencer.ticket()
        var cleared = false
        var written = false

        XCTAssertTrue(sequencer.applyClear(clear) { keeping in
            XCTAssertTrue(keeping.isEmpty)
            cleared = true
        })
        XCTAssertFalse(sequencer.apply(write, key: "server") { written = true })
        XCTAssertTrue(cleared)
        XCTAssertFalse(written)
    }

    func testLaterWriteAfterClearRuns() {
        let clear = sequencer.ticket()
        let write = sequencer.ticket()
        var written = false

        XCTAssertTrue(sequencer.applyClear(clear) { _ in })
        XCTAssertTrue(sequencer.apply(write, key: "server") { written = true })
        XCTAssertTrue(written)
    }

    func testClearAfterALaterWriteKeepsThatWriteAndClearsTheRest() {
        // removeAll commits before add(B), but B's mirror write lands first: the clear still runs so the
        // rows of the removed servers go, while B, which is newer than the clear, stays.
        let olderWrite = sequencer.ticket()
        let clear = sequencer.ticket()
        let newerWrite = sequencer.ticket()
        var kept: Set<String>?

        XCTAssertTrue(sequencer.apply(olderWrite, key: "a") {})
        XCTAssertTrue(sequencer.apply(newerWrite, key: "b") {})
        XCTAssertTrue(sequencer.applyClear(clear) { kept = $0 })
        XCTAssertEqual(kept, ["b"])

        // the clear is now the barrier for everything older than it, "a" included
        XCTAssertFalse(sequencer.apply(olderWrite, key: "a") {})
        XCTAssertFalse(sequencer.apply(clear, key: "c") {})
    }

    func testClearIsSkippedWhenALaterClearAlreadyLanded() {
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        var count = 0

        XCTAssertTrue(sequencer.applyClear(second) { _ in count += 1 })
        XCTAssertFalse(sequencer.applyClear(first) { _ in count += 1 })
        XCTAssertEqual(count, 1)
    }
}
