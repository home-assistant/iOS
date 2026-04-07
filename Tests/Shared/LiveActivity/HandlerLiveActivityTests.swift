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
        XCTAssertEqual(state.message, "")
        XCTAssertNil(state.criticalText)
        XCTAssertNil(state.progress)
        XCTAssertNil(state.progressMax)
        XCTAssertNil(state.chronometer)
        XCTAssertNil(state.countdownEnd)
        XCTAssertNil(state.icon)
        XCTAssertNil(state.color)
    }

    func testContentState_fullPayload_mapsAllFields() {
        let payload: [String: Any] = [
            "message": "Test message",
            "critical_text": "CRITICAL",
            "progress": 42,
            "progress_max": 100,
            "chronometer": true,
            "notification_icon": "mdi:home",
            "notification_icon_color": "#FF5733",
        ]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.message, "Test message")
        XCTAssertEqual(state.criticalText, "CRITICAL")
        XCTAssertEqual(state.progress, 42)
        XCTAssertEqual(state.progressMax, 100)
        XCTAssertEqual(state.chronometer, true)
        XCTAssertEqual(state.icon, "mdi:home")
        XCTAssertEqual(state.color, "#FF5733")
        XCTAssertNil(state.countdownEnd)
    }

    func testContentState_progressAsDouble_truncatesToInt() {
        // JSON may send progress as 50.0 (Double) rather than 50 (Int)
        let payload: [String: Any] = ["progress": NSNumber(value: 50.9)]
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.progress, 50)
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

    // MARK: - handle(_:) — app extension guard

    func testHandle_inAppExtension_skipsRegistryAndFulfills() {
        Current.isAppExtension = true
        let payload: [String: Any] = ["tag": "test-tag", "title": "Test"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
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

    func testHandle_missingTitle_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": "valid-tag"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
    }

    func testHandle_emptyTitle_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": "valid-tag", "title": ""]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
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

// MARK: - HandlerEndLiveActivity Tests

@available(iOS 17.2, *)
final class HandlerEndLiveActivityTests: XCTestCase {
    private var sut: HandlerEndLiveActivity!
    private var mockRegistry: MockLiveActivityRegistry!

    override func setUp() {
        super.setUp()
        sut = HandlerEndLiveActivity()
        mockRegistry = MockLiveActivityRegistry()
        Current.liveActivityRegistry = mockRegistry
        Current.isAppExtension = false
    }

    override func tearDown() {
        sut = nil
        mockRegistry = nil
        super.tearDown()
    }

    // MARK: - App extension guard

    func testHandle_inAppExtension_skipsRegistryAndFulfills() {
        Current.isAppExtension = true
        let payload: [String: Any] = ["tag": "test-tag"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.endCalls.isEmpty)
    }

    // MARK: - Tag validation

    func testHandle_missingTag_fulfillsWithoutCallingRegistry() {
        XCTAssertNoThrow(try hang(sut.handle([:])))
        XCTAssertTrue(mockRegistry.endCalls.isEmpty)
    }

    func testHandle_emptyTag_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": ""]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.endCalls.isEmpty)
    }

    func testHandle_invalidTag_fulfillsWithoutCallingRegistry() {
        let payload: [String: Any] = ["tag": "bad tag!"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.endCalls.isEmpty)
    }

    // MARK: - Dismissal policy

    func testHandle_noDismissalPolicy_usesImmediate() {
        let payload: [String: Any] = ["tag": "end-tag"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertEqual(mockRegistry.endCalls[0].tag, "end-tag")
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsImmediate)
    }

    func testHandle_defaultDismissalPolicy_usesDefault() {
        let payload: [String: Any] = ["tag": "end-tag", "dismissal_policy": "default"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsDefault)
    }

    func testHandle_afterDismissalPolicy_usesAfterPolicy() {
        let future = Date().addingTimeInterval(60)
        let payload: [String: Any] = [
            "tag": "end-tag",
            "dismissal_policy": "after:\(future.timeIntervalSince1970)",
        ]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        // Verify an .after policy was chosen (not .immediate or .default)
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsAfter)
        // Verify the stored policy matches the expected date (ActivityUIDismissalPolicy is Equatable)
        let expectedDate = Date(timeIntervalSince1970: future.timeIntervalSince1970)
        XCTAssertEqual(mockRegistry.endCalls[0].policy, .after(expectedDate))
    }

    func testHandle_afterDismissalPolicy_capsAt24Hours() {
        // A timestamp 48 hours in the future should be capped to ≤24 hours
        let farFuture = Date().addingTimeInterval(48 * 60 * 60)
        let payload: [String: Any] = [
            "tag": "end-tag",
            "dismissal_policy": "after:\(farFuture.timeIntervalSince1970)",
        ]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        let call = mockRegistry.endCalls[0]
        // The policy should be .after (not .immediate), confirming it wasn't discarded
        XCTAssertTrue(call.policyIsAfter)
        // The stored date must not equal the uncapped far-future date
        XCTAssertNotEqual(call.policy, .after(Date(timeIntervalSince1970: farFuture.timeIntervalSince1970)))
    }

    func testHandle_afterDismissalPolicyWithInvalidTimestamp_usesImmediate() {
        let payload: [String: Any] = ["tag": "end-tag", "dismissal_policy": "after:not-a-number"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsImmediate)
    }

    func testHandle_unknownDismissalPolicy_usesImmediate() {
        let payload: [String: Any] = ["tag": "end-tag", "dismissal_policy": "unknown"]
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsImmediate)
    }
}
#endif
