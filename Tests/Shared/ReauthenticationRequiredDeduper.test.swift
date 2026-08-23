@testable import Shared
import XCTest

final class ReauthenticationRequiredDeduperTests: XCTestCase {
    func testSecondCallForTheSameServerInsideTheWindowIsDropped() {
        var now = Date(timeIntervalSince1970: 1_000)
        let deduper = ReauthenticationRequiredDeduper(date: { now })

        XCTAssertTrue(deduper.shouldNotify(serverId: "a"))
        XCTAssertFalse(deduper.shouldNotify(serverId: "a"))

        now.addTimeInterval(3)
        XCTAssertTrue(deduper.shouldNotify(serverId: "a"))
    }

    func testDifferentServerIsNotDropped() {
        let now = Date(timeIntervalSince1970: 1_000)
        let deduper = ReauthenticationRequiredDeduper(date: { now })

        XCTAssertTrue(deduper.shouldNotify(serverId: "a"))
        XCTAssertTrue(deduper.shouldNotify(serverId: "b"))
    }
}
