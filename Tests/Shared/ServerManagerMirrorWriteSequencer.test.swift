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

        XCTAssertTrue(sequencer.applyClear(clear) { cleared = true })
        XCTAssertFalse(sequencer.apply(write, key: "server") { written = true })
        XCTAssertTrue(cleared)
        XCTAssertFalse(written)
    }

    func testLaterWriteAfterClearRuns() {
        let clear = sequencer.ticket()
        let write = sequencer.ticket()
        var written = false

        XCTAssertTrue(sequencer.applyClear(clear) {})
        XCTAssertTrue(sequencer.apply(write, key: "server") { written = true })
        XCTAssertTrue(written)
    }

    func testClearIsSkippedWhenALaterWriteAlreadyLanded() {
        let clear = sequencer.ticket()
        let write = sequencer.ticket()
        var cleared = false

        XCTAssertTrue(sequencer.apply(write, key: "server") {})
        XCTAssertFalse(sequencer.applyClear(clear) { cleared = true })
        XCTAssertFalse(cleared)
    }

    func testClearIsSkippedWhenALaterClearAlreadyLanded() {
        let first = sequencer.ticket()
        let second = sequencer.ticket()
        var count = 0

        XCTAssertTrue(sequencer.applyClear(second) { count += 1 })
        XCTAssertFalse(sequencer.applyClear(first) { count += 1 })
        XCTAssertEqual(count, 1)
    }
}
