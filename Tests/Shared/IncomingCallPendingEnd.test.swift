@testable import Shared
import XCTest

final class IncomingCallPendingEndTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "IncomingCallPendingEndTests")
        defaults.removePersistentDomain(forName: "IncomingCallPendingEndTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "IncomingCallPendingEndTests")
        Current.isAppExtension = false
        super.tearDown()
    }

    func testExtensionQueuesTheTag() {
        Current.isAppExtension = true
        IncomingCallPendingEnd.request(tag: "visio", defaults: defaults)
        IncomingCallPendingEnd.request(tag: "visio", defaults: defaults)
        IncomingCallPendingEnd.request(tag: "other", defaults: defaults)

        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults), ["visio", "other"])
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults), [])
    }

    func testAppPostsInProcess() {
        Current.isAppExtension = false
        let posted = expectation(forNotification: IncomingCallPendingEnd.didRequestEnd, object: "visio")
        IncomingCallPendingEnd.request(tag: "visio", defaults: defaults)
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults), [])
    }

    func testInvalidTagsAreIgnored() {
        Current.isAppExtension = true
        IncomingCallPendingEnd.request(tag: "not a tag", defaults: defaults)
        IncomingCallPendingEnd.request(tag: "", defaults: defaults)
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults), [])
    }

    func testQueueIsBounded() {
        for index in 0 ..< 40 {
            IncomingCallPendingEnd.append(tag: "tag\(index)", defaults: defaults)
        }
        let drained = IncomingCallPendingEnd.drainAll(defaults: defaults)
        XCTAssertEqual(drained.count, 16)
        XCTAssertEqual(drained.last, "tag39")
    }
}
