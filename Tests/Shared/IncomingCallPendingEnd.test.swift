@testable import Shared
import XCTest

final class IncomingCallPendingEndTests: XCTestCase {
    private var defaults: UserDefaults!
    private let date = Date(timeIntervalSince1970: 1_000_000)

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

    private func end(_ tag: String, server: String? = "server", at date: Date? = nil) -> IncomingCallEndRequest {
        .init(tag: tag, webhookID: server, date: date ?? self.date)
    }

    func testExtensionQueuesTheRequest() {
        Current.isAppExtension = true
        IncomingCallPendingEnd.request(end("visio"), defaults: defaults)
        IncomingCallPendingEnd.request(end("visio", at: date + 1), defaults: defaults)
        IncomingCallPendingEnd.request(end("other"), defaults: defaults)

        XCTAssertEqual(
            IncomingCallPendingEnd.drainAll(defaults: defaults, now: date + 2),
            [end("visio", at: date + 1), end("other")]
        )
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults, now: date + 2), [])
    }

    func testRequestsExpire() {
        Current.isAppExtension = true
        IncomingCallPendingEnd.request(end("visio"), defaults: defaults)
        XCTAssertEqual(
            IncomingCallPendingEnd.drainAll(defaults: defaults, now: date + IncomingCallPendingEnd.lifetime),
            []
        )
    }

    func testAppPostsInProcess() {
        Current.isAppExtension = false
        // A struct is boxed when posted, so match it explicitly rather than by object identity.
        let expected = end("visio")
        let posted = expectation(forNotification: IncomingCallPendingEnd.didRequestEnd, object: nil) { note in
            (note.object as? IncomingCallEndRequest) == expected
        }
        IncomingCallPendingEnd.request(end("visio"), defaults: defaults)
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults, now: date), [])
    }

    func testInvalidTagsAreIgnored() {
        Current.isAppExtension = true
        IncomingCallPendingEnd.request(end("not a tag"), defaults: defaults)
        IncomingCallPendingEnd.request(end(""), defaults: defaults)
        XCTAssertEqual(IncomingCallPendingEnd.drainAll(defaults: defaults, now: date), [])
    }

    func testQueueIsBounded() {
        for index in 0 ..< 40 {
            IncomingCallPendingEnd.append(end("tag\(index)"), defaults: defaults)
        }
        let drained = IncomingCallPendingEnd.drainAll(defaults: defaults, now: date)
        XCTAssertEqual(drained.count, 16)
        XCTAssertEqual(drained.last?.tag, "tag39")
    }

    func testARequestOnlyEndsItsServersCallThatAlreadyRang() {
        let request = end("visio", server: "a")
        XCTAssertTrue(request.ends(tag: "visio", webhookID: "a", startedAt: date - 10))
        XCTAssertTrue(request.ends(tag: "visio", webhookID: "a", startedAt: date))
        XCTAssertFalse(request.ends(tag: "visio", webhookID: "b", startedAt: date - 10), "another server")
        XCTAssertFalse(request.ends(tag: "other", webhookID: "a", startedAt: date - 10), "another tag")
        XCTAssertFalse(request.ends(tag: "visio", webhookID: "a", startedAt: date + 1), "a newer call")
    }
}
