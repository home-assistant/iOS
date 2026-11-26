@testable import Shared
import XCTest

final class IncomingCallGuardTests: XCTestCase {
    private var defaults: UserDefaults!
    private var date: Date!
    private var callGuard: IncomingCallGuard!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "IncomingCallGuardTests")
        defaults.removePersistentDomain(forName: "IncomingCallGuardTests")
        date = Date(timeIntervalSince1970: 1_000_000)
        callGuard = IncomingCallGuard(defaults: defaults, now: { [unowned self] in date })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "IncomingCallGuardTests")
        super.tearDown()
    }

    func testFirstCallRings() {
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
    }

    func testSameTagIsADuplicateUntilTheWindowPasses() {
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
        date += 60
        XCTAssertEqual(callGuard.admit(tag: "a"), .duplicate)
        date += IncomingCallGuard.duplicateWindow
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
    }

    func testTooManyCallsAreRateLimited() {
        for index in 0 ..< IncomingCallGuard.maximumCalls {
            XCTAssertEqual(callGuard.admit(tag: "call\(index)"), .ring)
            date += 1
        }
        XCTAssertEqual(callGuard.admit(tag: "one-more"), .rateLimited)

        date += IncomingCallGuard.rateWindow
        XCTAssertEqual(callGuard.admit(tag: "one-more"), .ring)
    }

    func testARateLimitedCallIsNotRecorded() {
        for index in 0 ..< IncomingCallGuard.maximumCalls {
            _ = callGuard.admit(tag: "call\(index)")
        }
        XCTAssertEqual(callGuard.admit(tag: "late"), .rateLimited)
        date += IncomingCallGuard.rateWindow
        // Not a duplicate: it never rang.
        XCTAssertEqual(callGuard.admit(tag: "late"), .ring)
    }

    func testHistoryIsSharedThroughTheDefaults() {
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
        let other = IncomingCallGuard(defaults: defaults, now: { [unowned self] in date })
        XCTAssertEqual(other.admit(tag: "a"), .duplicate)
    }

    func testReset() {
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
        callGuard.reset()
        XCTAssertEqual(callGuard.admit(tag: "a"), .ring)
    }
}
