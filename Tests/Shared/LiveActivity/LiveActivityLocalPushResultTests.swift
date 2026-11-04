#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import XCTest

final class LiveActivityLocalPushResultTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = LiveActivityLocalPushResult.take(confirmIDs: ["a", "b"])
    }

    override func tearDown() {
        _ = LiveActivityLocalPushResult.take(confirmIDs: ["a", "b"])
        super.tearDown()
    }

    func testTakeReturnsRecordedOutcomeOnce() {
        LiveActivityLocalPushResult.record(.presented, confirmID: "a")

        XCTAssertEqual(LiveActivityLocalPushResult.take(confirmIDs: ["a"]), ["a": .presented])
        XCTAssertTrue(LiveActivityLocalPushResult.take(confirmIDs: ["a"]).isEmpty)
    }

    func testTakeLeavesOtherConfirmIDsInPlace() {
        LiveActivityLocalPushResult.record(.presented, confirmID: "a")
        LiveActivityLocalPushResult.record(.notPresented, confirmID: "b")

        XCTAssertEqual(LiveActivityLocalPushResult.take(confirmIDs: ["a"]), ["a": .presented])
        XCTAssertEqual(LiveActivityLocalPushResult.take(confirmIDs: ["a", "b"]), ["b": .notPresented])
    }

    func testTakeUnknownConfirmIDIsEmpty() {
        XCTAssertTrue(LiveActivityLocalPushResult.take(confirmIDs: ["a"]).isEmpty)
    }

    func testLatestOutcomeWins() {
        LiveActivityLocalPushResult.record(.presented, confirmID: "a")
        LiveActivityLocalPushResult.record(.notPresented, confirmID: "a")

        XCTAssertEqual(LiveActivityLocalPushResult.take(confirmIDs: ["a"]), ["a": .notPresented])
    }
}
#endif
