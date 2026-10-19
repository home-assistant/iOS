#if canImport(ActivityKit)
import ActivityKit
import Foundation
@testable import Shared
import XCTest

@available(iOS 17.2, *)
final class LiveActivityPendingEndTests: XCTestCase {
    private var mockRegistry: MockLiveActivityRegistry!

    override func setUp() {
        super.setUp()
        mockRegistry = MockLiveActivityRegistry()
        Current.liveActivityRegistry = mockRegistry
        clearAppGroupState()
    }

    override func tearDown() {
        clearAppGroupState()
        mockRegistry = nil
        super.tearDown()
    }

    private func clearAppGroupState() {
        _ = LiveActivityPendingEnd.drainAll()
        _ = LiveActivityPendingStart.drainAll()
        _ = LiveActivityLocalPushResult.take(confirmIDs: ["confirm-1", "confirm-2"])
    }

    func testAppend_sameTag_keepsLatestConfirmID() {
        LiveActivityPendingEnd.append(tag: "tag", confirmID: "confirm-1")
        LiveActivityPendingEnd.append(tag: "tag", confirmID: "confirm-2")

        XCTAssertEqual(LiveActivityPendingEnd.drainAll(), [.init(tag: "tag", confirmID: "confirm-2")])
        XCTAssertTrue(LiveActivityPendingEnd.drainAll().isEmpty)
    }

    func testAppend_dropsQueuedStartForSameTag() {
        LiveActivityPendingStart.append(LiveActivityPendingStart.Request(
            tag: "tag",
            title: "T",
            serverWebhookId: nil,
            state: HandlerStartOrUpdateLiveActivity.contentState(from: ["message": "m"]),
            alert: false
        ))
        LiveActivityPendingEnd.append(tag: "tag")

        XCTAssertTrue(LiveActivityPendingStart.drainAll().isEmpty)
    }

    func testRemove_dropsOnlyThatTag() {
        LiveActivityPendingEnd.append(tag: "a")
        LiveActivityPendingEnd.append(tag: "b", confirmID: "confirm-1")
        LiveActivityPendingEnd.remove(tag: "a")

        XCTAssertEqual(LiveActivityPendingEnd.drainAll(), [.init(tag: "b", confirmID: "confirm-1")])
    }

    func testDrainAll_includesTagsQueuedByOlderBuilds() {
        queueLegacyTags(["legacy"])

        XCTAssertEqual(LiveActivityPendingEnd.drainAll(), [.init(tag: "legacy", confirmID: nil)])
        XCTAssertTrue(LiveActivityPendingEnd.drainAll().isEmpty)
    }

    func testAppend_keepsTagsQueuedByOlderBuilds() {
        queueLegacyTags(["legacy", "tag"])
        LiveActivityPendingEnd.append(tag: "tag", confirmID: "confirm-1")

        XCTAssertEqual(
            LiveActivityPendingEnd.drainAll(),
            [.init(tag: "legacy", confirmID: nil), .init(tag: "tag", confirmID: "confirm-1")]
        )
    }

    func testNewerStart_cancelsEndQueuedByOlderBuild() {
        queueLegacyTags(["tag"])
        LiveActivityPendingStart.append(LiveActivityPendingStart.Request(
            tag: "tag",
            title: "T",
            serverWebhookId: nil,
            state: HandlerStartOrUpdateLiveActivity.contentState(from: ["message": "m"]),
            alert: false
        ))

        XCTAssertTrue(LiveActivityPendingEnd.drainAll().isEmpty)
    }

    func testHandOff_queuesEndWithPushConfirmID() {
        LiveActivityPendingEnd.handOff(tag: "tag", payload: ["hass_confirm_id": "confirm-1"])

        XCTAssertEqual(LiveActivityPendingEnd.drainAll(), [.init(tag: "tag", confirmID: "confirm-1")])
    }

    func testDrainAll_dropsUndecodableQueue() {
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)
        defaults?.set(Data("not json".utf8), forKey: "liveActivityPendingEndRequests")

        XCTAssertTrue(LiveActivityPendingEnd.drainAll().isEmpty)
        XCTAssertNil(defaults?.data(forKey: "liveActivityPendingEndRequests"))
    }

    func testDrain_endsActivityAndReportsToExtension() {
        LiveActivityPendingEnd.append(tag: "tag", confirmID: "confirm-1")
        LiveActivityPendingEndObserver.drain()

        XCTAssertEqual(waitForLocalPushResult("confirm-1"), .presented)
        XCTAssertEqual(mockRegistry.endCalls.map(\.tag), ["tag"])
        XCTAssertTrue(mockRegistry.endCalls.allSatisfy(\.policyIsImmediate))
    }

    func testDrain_withoutConfirmID_reportsNothing() {
        LiveActivityPendingEnd.append(tag: "tag")
        LiveActivityPendingEndObserver.drain()
        waitUntil { !mockRegistry.endCalls.isEmpty }

        XCTAssertEqual(mockRegistry.endCalls.map(\.tag), ["tag"])
        XCTAssertTrue(LiveActivityLocalPushResult.take(confirmIDs: ["confirm-1"]).isEmpty)
    }

    private func queueLegacyTags(_ tags: [String]) {
        UserDefaults(suiteName: AppConstants.AppGroupID)?.set(tags, forKey: "liveActivityPendingEndTags")
    }

    private func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func waitForLocalPushResult(_ confirmID: String) -> LiveActivityLocalPushResult.Outcome? {
        var outcome: LiveActivityLocalPushResult.Outcome?
        waitUntil {
            outcome = LiveActivityLocalPushResult.take(confirmIDs: [confirmID])[confirmID]
            return outcome != nil
        }
        return outcome
    }
}
#endif
