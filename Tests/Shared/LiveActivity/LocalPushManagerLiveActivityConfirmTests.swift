#if os(iOS) && !targetEnvironment(macCatalyst)
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import XCTest

/// Extension-side flow of a Live Activity push over local push: the confirm waits for the app's
/// reply (`LiveActivityLocalPushResult`), and silence or a refusal re-opens the channel.
@available(iOS 17.2, *)
final class LocalPushManagerLiveActivityConfirmTests: XCTestCase {
    private var manager: LocalPushManager!
    private var api: FakeHomeAssistantAPI!
    private var apiConnection: HAMockConnection!
    private var delegate: DelegateSpy!
    private var previousIsAppExtension = false
    private var previousPushID: String?

    private final class DelegateSpy: LocalPushManagerDelegate {
        var received: [[AnyHashable: Any]] = []

        func localPushManager(
            _ manager: LocalPushManager,
            didReceiveRemoteNotification userInfo: [AnyHashable: Any]
        ) {
            received.append(userInfo)
        }
    }

    override func setUp() {
        super.setUp()
        previousIsAppExtension = Current.isAppExtension
        previousPushID = Current.settingsStore.pushID
        Current.isAppExtension = true
        Current.settingsStore.pushID = "push-id"

        let servers = FakeServerManager()
        Current.servers = servers
        let server = servers.addFake()
        server.info.connection.webhookID = "webhook1"
        api = FakeHomeAssistantAPI(server: server)
        apiConnection = HAMockConnection()
        api.connection = apiConnection
        Current.cachedApis[server.identifier] = api

        clearAppGroupState()

        delegate = DelegateSpy()
        manager = LocalPushManager(server: server)
        manager.delegate = delegate
        manager.add = { _ in .value(()) }
    }

    override func tearDown() {
        manager = nil
        Current.isAppExtension = previousIsAppExtension
        Current.settingsStore.pushID = previousPushID
        clearAppGroupState()
        super.tearDown()
    }

    private func clearAppGroupState() {
        _ = LiveActivityPendingStart.drainAll()
        _ = LiveActivityPendingEnd.drainAll()
        _ = LiveActivityLocalPushResult.take(confirmIDs: ["confirm-1", "confirm-2", "confirm-end"])
        UserDefaults(suiteName: AppConstants.AppGroupID)?
            .removeObject(forKey: LiveActivityRegistry.reportedTokenTagsKey)
    }

    /// Records that Core holds a push token for the activity, as the registry does once it runs.
    private func markActivityRunning(tag: String = "test_tag") {
        UserDefaults(suiteName: AppConstants.AppGroupID)?
            .set([tag], forKey: LiveActivityRegistry.reportedTokenTagsKey)
    }

    private func receiveEnd(confirmID: String? = "confirm-end", tag: String = "test_tag") throws {
        try receive(message: "clear_notification", data: ["tag": tag], confirmID: confirmID)
    }

    private func receiveLiveActivityPush(confirmID: String? = "confirm-1", tag: String? = "test_tag") throws {
        var data: [String: Any] = ["live_update": true]
        if let tag {
            data["tag"] = tag
        }
        try receive(message: "test_message", data: data, confirmID: confirmID)
    }

    private func receive(message: String, data: [String: Any], confirmID: String?) throws {
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.last)
        var payload: [String: Any] = ["message": message, "data": data]
        if let confirmID {
            payload["hass_confirm_id"] = confirmID
        }
        sub.handler(sub.cancellable, .dictionary(payload))
        drainMainQueue()
    }

    private func drainMainQueue() {
        let expectation = expectation(description: "main queue")
        DispatchQueue.main.async(execute: expectation.fulfill)
        wait(for: [expectation], timeout: 10)
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private var confirmedIDs: [String] {
        apiConnection.pendingRequests
            .filter { $0.request.type == "mobile_app/push_notification_confirm" }
            .compactMap { $0.request.data["confirm_id"] as? String }
    }

    private func makeQueuedRequest(tag: String = "test_tag") -> LiveActivityPendingStart.Request {
        LiveActivityPendingStart.Request(
            tag: tag,
            title: "T",
            serverWebhookId: nil,
            state: HandlerStartOrUpdateLiveActivity.contentState(from: ["message": "m"]),
            confirmID: "confirm-1",
            alert: true
        )
    }

    func testDefersConfirmAndHandsOffConfirmID() throws {
        try receiveLiveActivityPush()

        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertEqual(delegate.received.count, 1)
        XCTAssertEqual(delegate.received.first?["hass_confirm_id"] as? String, "confirm-1")
        XCTAssertEqual(manager.liveActivityConfirms.pendingConfirmIDs, ["confirm-1"])
        XCTAssertEqual(apiConnection.pendingSubscriptions.count, 1)
    }

    func testConfirmsWhenAppReportsPresented() throws {
        try receiveLiveActivityPush()

        LiveActivityLocalPushResult.record(.presented, confirmID: "confirm-1")
        LiveActivityLocalPushResult.postDarwinSignal()
        waitUntil { !confirmedIDs.isEmpty }

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        XCTAssertEqual(apiConnection.pendingSubscriptions.count, 1, "channel is kept as is")
    }

    func testReopensChannelWhenAppCouldNotPresent() throws {
        LiveActivityPendingStart.append(makeQueuedRequest())
        try receiveLiveActivityPush()
        let original = try XCTUnwrap(apiConnection.pendingSubscriptions.first)

        LiveActivityLocalPushResult.record(.notPresented, confirmID: "confirm-1")
        LiveActivityLocalPushResult.postDarwinSignal()
        waitUntil { apiConnection.pendingSubscriptions.count == 2 }

        XCTAssertTrue(original.cancellable.wasCancelled)
        let reopened = try XCTUnwrap(apiConnection.pendingSubscriptions.last)
        XCTAssertEqual(reopened.request.type, "mobile_app/push_notification_channel")
        XCTAssertEqual(reopened.request.data["webhook_id"] as? String, "webhook1")
        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        XCTAssertTrue(LiveActivityPendingStart.drainAll().isEmpty, "APNs owns the start now")
    }

    func testReopensChannelWhenAppDoesNotReply() throws {
        manager.liveActivityConfirms.replyTimeout = 0.05
        let original = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        original.initiated(.success(.empty))
        try receiveLiveActivityPush()
        XCTAssertEqual(manager.state, .available(received: 1))

        waitUntil { apiConnection.pendingSubscriptions.count == 2 }

        XCTAssertTrue(original.cancellable.wasCancelled)
        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        // Re-opening is not a disconnect: the state and the received count carry over.
        XCTAssertEqual(manager.state, .available(received: 1))
        let reopened = try XCTUnwrap(apiConnection.pendingSubscriptions.last)
        reopened.initiated(.success(.empty))
        XCTAssertEqual(manager.state, .available(received: 1))
    }

    func testReplyRecordedBeforeRegistrationIsConsumed() throws {
        // The app can answer before the tracker's main-queue registration runs; that reply must
        // still confirm the push instead of letting it time out into an APNs re-send.
        LiveActivityLocalPushResult.record(.presented, confirmID: "confirm-1")
        try receiveLiveActivityPush()

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        XCTAssertEqual(apiConnection.pendingSubscriptions.count, 1)
    }

    func testUpdatesForSameTagKeepTheOriginalDeadline() throws {
        manager.liveActivityConfirms.replyTimeout = 1
        let start = Date()
        try receiveLiveActivityPush(confirmID: "confirm-1")
        waitUntil({ false }, timeout: 0.7)
        try receiveLiveActivityPush(confirmID: "confirm-2")

        waitUntil({ apiConnection.pendingSubscriptions.count == 2 }, timeout: 5)

        // A fresh deadline for the second push would fall back no earlier than 1.7 s.
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5)
        XCTAssertEqual(apiConnection.pendingSubscriptions.count, 2)
        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testNewerStartForSameTagConfirmsOlderPush() throws {
        try receiveLiveActivityPush(confirmID: "confirm-1")
        try receiveLiveActivityPush(confirmID: "confirm-2")

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertEqual(manager.liveActivityConfirms.pendingConfirmIDs, ["confirm-2"])
    }

    func testClearNotificationForSameTagConfirmsPendingStart() throws {
        try receiveLiveActivityPush()
        try receive(message: "clear_notification", data: ["tag": "test_tag"], confirmID: "confirm-end")

        XCTAssertEqual(Set(confirmedIDs), ["confirm-1", "confirm-end"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testDefersEndConfirmForRunningActivity() throws {
        markActivityRunning()
        try receiveEnd()

        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertEqual(delegate.received.first?["hass_confirm_id"] as? String, "confirm-end")
        XCTAssertEqual(manager.liveActivityConfirms.pendingConfirmIDs, ["confirm-end"])
    }

    func testConfirmsEndWhenAppReportsIt() throws {
        markActivityRunning()
        try receiveEnd()

        LiveActivityLocalPushResult.record(.presented, confirmID: "confirm-end")
        LiveActivityLocalPushResult.postDarwinSignal()
        waitUntil { !confirmedIDs.isEmpty }

        XCTAssertEqual(confirmedIDs, ["confirm-end"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        XCTAssertEqual(apiConnection.pendingSubscriptions.count, 1, "channel is kept as is")
    }

    func testReopensChannelWhenAppDoesNotEnd() throws {
        manager.liveActivityConfirms.replyTimeout = 0.05
        markActivityRunning()
        LiveActivityPendingEnd.append(tag: "test_tag", confirmID: "confirm-end")
        let original = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        try receiveEnd()

        waitUntil { apiConnection.pendingSubscriptions.count == 2 }

        XCTAssertTrue(original.cancellable.wasCancelled)
        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
        XCTAssertTrue(LiveActivityPendingEnd.drainAll().isEmpty, "APNs owns the end now")
    }

    func testEndForRunningActivityConfirmsPendingUpdate() throws {
        markActivityRunning()
        try receiveLiveActivityPush()
        try receiveEnd()

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertEqual(manager.liveActivityConfirms.pendingConfirmIDs, ["confirm-end"])
    }

    func testConfirmsEndImmediatelyForOtherTags() throws {
        // A clear for a tag without a running activity is an ordinary notification clear.
        markActivityRunning(tag: "other_tag")
        try receiveEnd()

        XCTAssertEqual(confirmedIDs, ["confirm-end"])
        XCTAssertNil(delegate.received.first?["hass_confirm_id"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testConfirmsImmediatelyWithoutRemotePush() throws {
        Current.settingsStore.pushID = nil
        try receiveLiveActivityPush()

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertNil(delegate.received.first?["hass_confirm_id"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testConfirmsImmediatelyWithoutTag() throws {
        try receiveLiveActivityPush(tag: nil)

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testConfirmsImmediatelyOutsideExtension() throws {
        Current.isAppExtension = false
        try receiveLiveActivityPush()

        XCTAssertEqual(confirmedIDs, ["confirm-1"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }

    func testWithoutConfirmIDNothingIsTracked() throws {
        try receiveLiveActivityPush(confirmID: nil)

        XCTAssertTrue(confirmedIDs.isEmpty)
        XCTAssertNil(delegate.received.first?["hass_confirm_id"])
        XCTAssertTrue(manager.liveActivityConfirms.pendingConfirmIDs.isEmpty)
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
#endif
