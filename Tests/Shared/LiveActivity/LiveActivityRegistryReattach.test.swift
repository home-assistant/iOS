#if canImport(ActivityKit)
import ActivityKit
import Foundation
import PromiseKit
@testable import Shared
import XCTest

/// Exercises the real `LiveActivityRegistry` actor along the paths that need no running
/// `Activity` (the test process has none): ending an unknown tag, and the launch-time release of
/// push tokens Core still holds for activities that are gone.
@available(iOS 17.2, *)
final class LiveActivityRegistryReattachTests: XCTestCase {
    private static let reportedTokenTagsKey = "liveActivityReportedTokenTags"

    private var servers: FakeServerManager!
    private var webhooks: FakeWebhookManager!
    private var previousServers: ServerManager!
    private var previousWebhooks: WebhookManager!
    private var previousReportedTags: Any?

    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.AppGroupID)!
    }

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousWebhooks = Current.webhooks
        previousReportedTags = defaults.object(forKey: Self.reportedTokenTagsKey)

        servers = FakeServerManager()
        Current.servers = servers
        webhooks = FakeWebhookManager()
        Current.webhooks = webhooks
    }

    override func tearDown() {
        if let previousReportedTags {
            defaults.set(previousReportedTags, forKey: Self.reportedTokenTagsKey)
        } else {
            defaults.removeObject(forKey: Self.reportedTokenTagsKey)
        }
        Current.servers = previousServers
        Current.webhooks = previousWebhooks
        super.tearDown()
    }

    private var reportedTags: Set<String> {
        Set(defaults.stringArray(forKey: Self.reportedTokenTagsKey) ?? [])
    }

    func testReattach_releasesTokensForTagsThatAreNoLongerRunning() async {
        _ = servers.addFake()
        defaults.set(["gone-tag"], forKey: Self.reportedTokenTagsKey)

        let sent = expectation(description: "dismissal reported")
        var requests: [WebhookRequest] = []
        webhooks.sendEphemeralHandler = { _, request in
            requests.append(request)
            sent.fulfill()
            return [String: Any]()
        }

        await LiveActivityRegistry().reattach()
        await fulfillment(of: [sent], timeout: 10)

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.type, LiveActivityRegistry.webhookTypeDismissed)
        XCTAssertEqual(requests.first?.data as? [String: String], ["tag": "gone-tag"])

        let forgotten = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in self?.reportedTags.isEmpty == true },
            object: nil
        )
        await fulfillment(of: [forgotten], timeout: 10)
    }

    func testReattach_keepsTagWhenDismissalIsNotConfirmed() async {
        _ = servers.addFake()
        defaults.set(["offline-tag"], forKey: Self.reportedTokenTagsKey)
        // No handler: the fake rejects the send, as an offline device would, so the tag must be kept
        // for the next launch to retry.
        webhooks.sendEphemeralHandler = nil

        await LiveActivityRegistry().reattach()

        XCTAssertEqual(reportedTags, ["offline-tag"])
    }

    func testReattach_withNoServers_forgetsStaleTag() async {
        defaults.set(["orphan-tag"], forKey: Self.reportedTokenTagsKey)

        await LiveActivityRegistry().reattach()

        // With no server to tell, the (empty) set of sends succeeds at once and the tag is dropped.
        let forgotten = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in self?.reportedTags.isEmpty == true },
            object: nil
        )
        await fulfillment(of: [forgotten], timeout: 10)
    }

    func testReattach_withNoReportedTokens_sendsNothing() async {
        _ = servers.addFake()
        defaults.removeObject(forKey: Self.reportedTokenTagsKey)

        var sendCount = 0
        webhooks.sendEphemeralHandler = { _, _ in
            sendCount += 1
            return [String: Any]()
        }

        await LiveActivityRegistry().reattach()

        XCTAssertEqual(sendCount, 0)
        XCTAssertTrue(reportedTags.isEmpty)
    }

    func testEnd_unknownTag_sendsNothing() async {
        _ = servers.addFake()
        var sendCount = 0
        webhooks.sendEphemeralHandler = { _, _ in
            sendCount += 1
            return [String: Any]()
        }

        let registry = LiveActivityRegistry()
        await registry.end(tag: "never-started", dismissalPolicy: .immediate)
        await registry.end(tag: "never-started")

        XCTAssertEqual(sendCount, 0)
    }
}
#endif
