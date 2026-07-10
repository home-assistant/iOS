#if canImport(ActivityKit)
import Foundation
import PromiseKit
@testable import Shared
import XCTest

// MARK: - HandlerStartOrUpdateLiveActivity Tests

@available(iOS 17.2, *)
final class HandlerStartOrUpdateLiveActivityTests: XCTestCase {
    private var sut: HandlerStartOrUpdateLiveActivity!
    private var mockRegistry: MockLiveActivityRegistry!

    override func setUp() {
        super.setUp()
        sut = HandlerStartOrUpdateLiveActivity()
        mockRegistry = MockLiveActivityRegistry()
        Current.liveActivityRegistry = mockRegistry
        Current.isAppExtension = false
        // Clear any cross-process hand-off queue left over from a prior test.
        _ = LiveActivityPendingStart.drainAll()
    }

    override func tearDown() {
        sut = nil
        mockRegistry = nil
        super.tearDown()
    }

    // MARK: - isValidTag

    func testIsValidTag_alphanumericOnly_isValid() {
        XCTAssertTrue(HandlerStartOrUpdateLiveActivity.isValidTag("abc123"))
    }

    func testIsValidTag_withHyphen_isValid() {
        XCTAssertTrue(HandlerStartOrUpdateLiveActivity.isValidTag("ha-tag"))
    }

    func testIsValidTag_withUnderscore_isValid() {
        XCTAssertTrue(HandlerStartOrUpdateLiveActivity.isValidTag("ha_tag"))
    }

    func testIsValidTag_exactly64Chars_isValid() {
        let tag = String(repeating: "a", count: 64)
        XCTAssertTrue(HandlerStartOrUpdateLiveActivity.isValidTag(tag))
    }

    func testIsValidTag_65Chars_isInvalid() {
        let tag = String(repeating: "a", count: 65)
        XCTAssertFalse(HandlerStartOrUpdateLiveActivity.isValidTag(tag))
    }

    func testIsValidTag_withSpace_isInvalid() {
        XCTAssertFalse(HandlerStartOrUpdateLiveActivity.isValidTag("ha tag"))
    }

    func testIsValidTag_withDot_isInvalid() {
        XCTAssertFalse(HandlerStartOrUpdateLiveActivity.isValidTag("ha.tag"))
    }

    func testIsValidTag_withSlash_isInvalid() {
        XCTAssertFalse(HandlerStartOrUpdateLiveActivity.isValidTag("ha/tag"))
    }

    func testIsValidTag_withAtSign_isInvalid() {
        XCTAssertFalse(HandlerStartOrUpdateLiveActivity.isValidTag("ha@tag"))
    }

    func testIsValidTag_emptyString_isValid() {
        // isValidTag uses allSatisfy which returns true vacuously for empty strings.
        // Empty tags are rejected earlier in handle() via the !tag.isEmpty guard,
        // so isValidTag is never called with an empty string in practice.
        XCTAssertTrue(HandlerStartOrUpdateLiveActivity.isValidTag(""))
    }

    // MARK: - contentState(from:)

    func testContentState_minimalPayload_usesDefaults() {
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: [:])
        XCTAssertNil(state.title)
        XCTAssertEqual(state.message, "")
        XCTAssertNil(state.criticalText)
        XCTAssertNil(state.progress)
        XCTAssertNil(state.progressMax)
        XCTAssertNil(state.chronometer)
        XCTAssertNil(state.countdownEnd)
        XCTAssertNil(state.icon)
        XCTAssertNil(state.color)
        XCTAssertNil(state.backgroundColor)
        XCTAssertNil(state.textColor)
        XCTAssertNil(state.progressBarColor)
    }

    func testContentState_emptyTitle_isNil() {
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: ["title": ""])
        XCTAssertNil(state.title)
    }

    func testContentState_fullPayload_mapsAllFields() {
        let payload: [String: Any] = [
            "title": "Test title",
            "message": "Test message",
            "critical_text": "CRITICAL",
            "progress": 42,
            "progress_max": 100,
            "chronometer": true,
            "notification_icon": "mdi:home",
            "notification_icon_color": "#FF5733",
            "background_color": "#101820",
            "text_color": "#FFFFFF",
            "progress_bar_color": "#FF9800",
        ]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.title, "Test title")
        XCTAssertEqual(state.message, "Test message")
        XCTAssertEqual(state.criticalText, "CRITICAL")
        XCTAssertEqual(state.progress, 42)
        XCTAssertEqual(state.progressMax, 100)
        XCTAssertEqual(state.chronometer, true)
        XCTAssertEqual(state.icon, "mdi:home")
        XCTAssertEqual(state.color, "#FF5733")
        XCTAssertEqual(state.backgroundColor, "#101820")
        XCTAssertEqual(state.textColor, "#FFFFFF")
        XCTAssertEqual(state.progressBarColor, "#FF9800")
        XCTAssertNil(state.countdownEnd)
    }

    func testContentState_progressAsDouble_roundsToInt() {
        // JSON may send progress as a float (e.g. 20.1234) rather than an Int; round to the nearest.
        let payload: [String: Any] = ["progress": NSNumber(value: 50.9), "progress_max": NSNumber(value: 100.4)]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.progress, 51)
        XCTAssertEqual(state.progressMax, 100)
    }

    func testContentState_progressNonFinite_isNil() {
        let payload: [String: Any] = [
            "progress": NSNumber(value: Double.nan),
            "progress_max": NSNumber(value: Double.infinity),
        ]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertNil(state.progress)
        XCTAssertNil(state.progressMax)
    }

    func testContentState_whenAbsolute_usesEpochTimestamp() {
        let timestamp: Double = 1_700_000_000
        let payload: [String: Any] = ["when": NSNumber(value: timestamp), "when_relative": false]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.countdownEnd?.timeIntervalSince1970 ?? 0, timestamp, accuracy: 0.001)
    }

    func testContentState_whenRelative_addsIntervalToNow() {
        let interval: Double = 300 // 5 minutes from now
        let payload: [String: Any] = ["when": NSNumber(value: interval), "when_relative": true]
        let before = Date()
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        let after = Date()

        guard let countdownEnd = state.countdownEnd else {
            return XCTFail("countdownEnd should not be nil")
        }
        XCTAssertGreaterThanOrEqual(countdownEnd.timeIntervalSince(before), interval - 0.1)
        XCTAssertLessThanOrEqual(countdownEnd.timeIntervalSince(after), interval + 0.1)
    }

    func testContentState_whenMissing_countdownEndIsNil() {
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: ["when_relative": true])
        XCTAssertNil(state.countdownEnd)
    }

    func testContentState_whenRelativePositive_hasNoChronometerStart() {
        let payload: [String: Any] = ["when": NSNumber(value: 300), "when_relative": true]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertNil(state.chronometerStart)
    }

    func testContentState_whenRelativeNegative_isBoundedCountUp() {
        // Negative relative `when` = bounded count-up: anchor at now, end |when| seconds later.
        let payload: [String: Any] = ["when": NSNumber(value: -1200), "when_relative": true]
        let before = Date()
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        let after = Date()

        guard let start = state.chronometerStart, let end = state.countdownEnd else {
            return XCTFail("bounded count-up should set both chronometerStart and countdownEnd")
        }
        XCTAssertGreaterThanOrEqual(start.timeIntervalSince1970, before.timeIntervalSince1970 - 0.1)
        XCTAssertLessThanOrEqual(start.timeIntervalSince1970, after.timeIntervalSince1970 + 0.1)
        XCTAssertEqual(end.timeIntervalSince(start), 1200, accuracy: 0.001)
    }

    func testContentState_whenAbsolutePast_hasNoChronometerStart() {
        // An absolute past `when` stays an unbounded count-up — no anchor, no freeze point.
        let payload: [String: Any] = ["when": NSNumber(value: 1_700_000_000), "when_relative": false]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertNil(state.chronometerStart)
        XCTAssertEqual(state.countdownEnd?.timeIntervalSince1970 ?? 0, 1_700_000_000, accuracy: 0.001)
    }

    // MARK: - handle(_:) — app extension hand-off

    func testHandle_inAppExtension_enqueuesHandoffAndSkipsRegistry() throws {
        Current.isAppExtension = true
        let payload: [String: Any] = [
            "tag": "test-tag",
            "title": "Test",
            "message": "Body",
            "webhook_id": "wh-1",
        ]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        // ActivityKit is unavailable in the extension, so the registry is not touched directly...
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
        // ...instead the request is handed off to the app via the App Group queue.
        let pending = LiveActivityPendingStart.drainAll()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.tag, "test-tag")
        XCTAssertEqual(pending.first?.title, "Test")
        XCTAssertEqual(pending.first?.serverWebhookId, "wh-1")
        XCTAssertEqual(pending.first?.state.message, "Body")
        // A non-silent update carries alert = true so the drain fires an ActivityKit alert.
        XCTAssertEqual(pending.first?.alert, true)
    }

    func testHandle_inAppExtension_silent_handsOffWithAlertFalse() throws {
        Current.isAppExtension = true
        let payload: [String: Any] = ["tag": "test-tag", "title": "Test", "silent": true]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        let pending = LiveActivityPendingStart.drainAll()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.alert, false)
    }

    func testHandle_inApp_passesAlertFalseToRegistry() throws {
        // APNs alerting is owned by the notification system (foreground willPresent / system
        // banner), so the in-app path never fires the ActivityKit alert.
        let payload: [String: Any] = ["tag": "my-activity", "title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertFalse(mockRegistry.startOrUpdateCalls[0].alert)
    }

    func testHandle_inAppExtension_invalidTag_doesNotEnqueue() throws {
        Current.isAppExtension = true
        let payload: [String: Any] = ["tag": "invalid tag", "title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
        XCTAssertTrue(LiveActivityPendingStart.drainAll().isEmpty)
    }

    // MARK: - handle(_:) — validation failures fulfill (no rejection)

    func testHandle_missingTag_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
    }

    func testHandle_emptyTag_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": "", "title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
    }

    func testHandle_invalidTag_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": "invalid tag with spaces", "title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
    }

    func testHandle_missingTitle_startsWithDefaultTitle() throws {
        let payload: [String: Any] = ["tag": "valid-tag"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].title, HALiveActivityAttributes.defaultTitle)
        XCTAssertNil(mockRegistry.startOrUpdateCalls[0].state.title)
    }

    func testHandle_emptyTitle_startsWithDefaultTitleAndNilStateTitle() throws {
        let payload: [String: Any] = ["tag": "valid-tag", "title": ""]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].title, HALiveActivityAttributes.defaultTitle)
        XCTAssertNil(mockRegistry.startOrUpdateCalls[0].state.title)
    }

    // MARK: - handle(_:) — successful path

    func testHandle_validPayload_callsRegistryStartOrUpdate() throws {
        let payload: [String: Any] = ["tag": "my-activity", "title": "My Title", "message": "Hello"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].tag, "my-activity")
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].title, "My Title")
    }

    func testHandle_registryThrows_rejectsPromise() {
        struct TestError: Error {}
        mockRegistry.startOrUpdateError = TestError()
        let payload: [String: Any] = ["tag": "my-activity", "title": "My Title"]
        XCTAssertThrowsError(try hang(sut.handle(payload)))
    }

    // MARK: - Privacy disclosure

    func testHandle_firstCall_setsDisclosureFlag() throws {
        Current.settingsStore.hasSeenLiveActivityDisclosure = false
        let payload: [String: Any] = ["tag": "priv-tag", "title": "Privacy Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(Current.settingsStore.hasSeenLiveActivityDisclosure)
    }

    func testHandle_disclosureAlreadySeen_doesNotChange() throws {
        Current.settingsStore.hasSeenLiveActivityDisclosure = true
        let payload: [String: Any] = ["tag": "priv-tag", "title": "Privacy Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        // Still true — unchanged
        XCTAssertTrue(Current.settingsStore.hasSeenLiveActivityDisclosure)
    }
}

// MARK: - LiveActivityRegistry token targeting

@available(iOS 17.2, *)
final class LiveActivityRegistryTokenTargetingTests: XCTestCase {
    private var servers: FakeServerManager!

    override func setUp() {
        super.setUp()
        servers = FakeServerManager()
        Current.servers = servers
    }

    override func tearDown() {
        servers = nil
        Current.servers = FakeServerManager()
        super.tearDown()
    }

    private func addServer(webhookID: String) {
        let info = with(ServerInfo.fake()) { $0.connection.webhookID = webhookID }
        _ = servers.add(identifier: .init(rawValue: webhookID), serverInfo: info)
    }

    /// A per-activity push token must go only to the server whose `webhook_id` started the activity.
    func testTokenTargetServers_reportsOnlyToOriginServer() {
        addServer(webhookID: "wh-1")
        addServer(webhookID: "wh-2")
        let targets = LiveActivityRegistry.tokenTargetServers(originWebhookID: "wh-2")
        XCTAssertEqual(targets.map(\.info.connection.webhookID), ["wh-2"])
    }

    /// Activities created before the origin was recorded carry no `webhook_id`, so their tokens
    /// still reach every server and existing activities keep working.
    func testTokenTargetServers_nilOrigin_reportsToAllServers() {
        addServer(webhookID: "wh-1")
        addServer(webhookID: "wh-2")
        let targets = LiveActivityRegistry.tokenTargetServers(originWebhookID: nil)
        XCTAssertEqual(Set(targets.map(\.info.connection.webhookID)), ["wh-1", "wh-2"])
    }

    /// If the origin id matches no current server (its server was removed, or the id is unrecognised),
    /// fall back to every server rather than silently dropping the token.
    func testTokenTargetServers_unknownOrigin_fallsBackToAllServers() {
        addServer(webhookID: "wh-1")
        addServer(webhookID: "wh-2")
        let targets = LiveActivityRegistry.tokenTargetServers(originWebhookID: "wh-removed")
        XCTAssertEqual(Set(targets.map(\.info.connection.webhookID)), ["wh-1", "wh-2"])
    }

    /// With no servers configured there is nowhere to report; the caller skips and remembers nothing.
    func testTokenTargetServers_noServers_returnsEmpty() {
        XCTAssertTrue(LiveActivityRegistry.tokenTargetServers(originWebhookID: "wh-1").isEmpty)
        XCTAssertTrue(LiveActivityRegistry.tokenTargetServers(originWebhookID: nil).isEmpty)
    }
}

// MARK: - LiveActivityRegistry bounded count-up anchor

@available(iOS 17.2, *)
final class LiveActivityRegistryChronometerAnchorTests: XCTestCase {
    private func countUpState(
        message: String = "m",
        start: Date,
        duration: TimeInterval
    ) -> HALiveActivityAttributes.ContentState {
        HALiveActivityAttributes.ContentState(
            message: message,
            chronometer: true,
            countdownEnd: start.addingTimeInterval(duration),
            chronometerStart: start
        )
    }

    /// An update re-sending the same negative `when` re-stamps the anchor at its own receipt
    /// time; carrying the previous anchor forward keeps the elapsed timer from resetting.
    func testCarryForward_sameDuration_keepsPreviousAnchor() {
        let previousStart = Date(timeIntervalSince1970: 1_700_000_000)
        let previous = countUpState(start: previousStart, duration: 1200)
        let new = countUpState(message: "updated", start: previousStart.addingTimeInterval(300), duration: 1200)

        let carried = LiveActivityRegistry.carryForwardChronometerAnchor(previous: previous, new: new)

        XCTAssertEqual(carried.chronometerStart, previous.chronometerStart)
        XCTAssertEqual(carried.countdownEnd, previous.countdownEnd)
        XCTAssertEqual(carried.message, "updated")
    }

    /// Sub-second parse jitter between the two stampings must not defeat the carry-forward.
    func testCarryForward_subSecondJitter_keepsPreviousAnchor() {
        let previousStart = Date(timeIntervalSince1970: 1_700_000_000)
        let previous = countUpState(start: previousStart, duration: 1200)
        let new = countUpState(start: previousStart.addingTimeInterval(300), duration: 1200.4)

        let carried = LiveActivityRegistry.carryForwardChronometerAnchor(previous: previous, new: new)

        XCTAssertEqual(carried.chronometerStart, previous.chronometerStart)
    }

    /// A different duration is a new timer — the update's own anchor applies.
    func testCarryForward_differentDuration_reanchors() {
        let previousStart = Date(timeIntervalSince1970: 1_700_000_000)
        let previous = countUpState(start: previousStart, duration: 1200)
        let new = countUpState(start: previousStart.addingTimeInterval(300), duration: 600)

        let carried = LiveActivityRegistry.carryForwardChronometerAnchor(previous: previous, new: new)

        XCTAssertEqual(carried.chronometerStart, new.chronometerStart)
        XCTAssertEqual(carried.countdownEnd, new.countdownEnd)
    }

    /// A previous state without an anchor (countdown or unbounded count-up) has nothing to carry.
    func testCarryForward_previousNotBounded_usesNewState() {
        let previous = HALiveActivityAttributes.ContentState(
            message: "m",
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newStart = Date(timeIntervalSince1970: 1_700_000_500)
        let new = countUpState(start: newStart, duration: 1200)

        let carried = LiveActivityRegistry.carryForwardChronometerAnchor(previous: previous, new: new)

        XCTAssertEqual(carried.chronometerStart, newStart)
    }

    /// An update that isn't a bounded count-up (e.g. switches to a countdown) passes through as-is.
    func testCarryForward_newNotBounded_usesNewState() {
        let previous = countUpState(start: Date(timeIntervalSince1970: 1_700_000_000), duration: 1200)
        let new = HALiveActivityAttributes.ContentState(
            message: "m",
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 1_700_005_000)
        )

        let carried = LiveActivityRegistry.carryForwardChronometerAnchor(previous: previous, new: new)

        XCTAssertNil(carried.chronometerStart)
        XCTAssertEqual(carried.countdownEnd, new.countdownEnd)
    }
}

#endif
