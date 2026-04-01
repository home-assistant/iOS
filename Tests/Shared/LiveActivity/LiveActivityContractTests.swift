#if canImport(ActivityKit)
import Foundation
@testable import Shared
import XCTest

/// Contract tests that validate wire-format frozen values won't change.
///
/// These values appear in APNs payloads, webhook requests, and notification routing.
/// Changing them would break communication with the HA server, relay server, or APNs.
/// If a test fails, it means a wire-format contract was broken — do not simply update
/// the expected value without coordinating with all server-side consumers.
@available(iOS 17.2, *)
final class LiveActivityContractTests: XCTestCase {
    // MARK: - HALiveActivityAttributes (wire-format frozen struct)

    /// The struct name appears as `attributes-type` in APNs push-to-start payloads.
    /// Renaming it silently breaks all remote starts.
    func testAttributesTypeName_isFrozen() {
        let typeName = String(describing: HALiveActivityAttributes.self)
        XCTAssertEqual(typeName, "HALiveActivityAttributes")
    }

    /// CodingKeys define the JSON field names in APNs content-state payloads.
    /// Adding new optional fields is safe; renaming or removing breaks in-flight activities.
    func testContentState_codingKeys_areFrozen() {
        let state = HALiveActivityAttributes.ContentState(
            message: "test",
            criticalText: "ct",
            progress: 1,
            progressMax: 2,
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 0),
            icon: "mdi:test",
            color: "#FF0000"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try! encoder.encode(state)
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        // These keys must match the Android notification field names exactly.
        let expectedKeys: Set<String> = [
            "message",
            "critical_text",
            "progress",
            "progress_max",
            "chronometer",
            "countdown_end",
            "icon",
            "color",
        ]
        XCTAssertEqual(Set(dict.keys), expectedKeys)
    }

    /// ContentState must round-trip through JSON without data loss.
    func testContentState_roundTrip_preservesAllFields() {
        let original = HALiveActivityAttributes.ContentState(
            message: "Cycle in progress",
            criticalText: "45 min",
            progress: 2700,
            progressMax: 3600,
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 1_700_000_000),
            icon: "mdi:washing-machine",
            color: "#2196F3"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(HALiveActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - LiveActivityRegistry (webhook contracts)

    /// The Keychain key for the push-to-start token. Changing it would lose stored tokens.
    func testPushToStartTokenKeychainKey_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.pushToStartTokenKeychainKey,
            "live_activity_push_to_start_token"
        )
    }

    /// Webhook type string for reporting a new per-activity push token.
    /// Must match the HA core webhook handler name.
    func testWebhookTypeToken_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.webhookTypeToken,
            "mobile_app_live_activity_token"
        )
    }

    /// Keys in the token webhook request data dictionary.
    /// Must match what HA core's update_live_activity_token handler expects.
    func testTokenWebhookKeys_areFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.tokenWebhookKeys,
            ["activity_id", "push_token", "apns_environment"]
        )
    }

    /// Webhook type string for reporting a dismissed activity.
    /// Must match the HA core webhook handler name.
    func testWebhookTypeDismissed_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.webhookTypeDismissed,
            "mobile_app_live_activity_dismissed"
        )
    }

    /// Keys in the dismissed webhook request data dictionary.
    /// Must match what HA core's live_activity_dismissed handler expects.
    func testDismissedWebhookKeys_areFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.dismissedWebhookKeys,
            ["activity_id", "live_activity_tag", "reason"]
        )
    }

    // MARK: - NotificationsCommandManager (command strings)

    /// The command strings that route to Live Activity handlers.
    /// Changing these breaks the HA → app notification contract.
    func testLiveActivityCommandStrings_areFrozen() {
        let manager = NotificationCommandManager()

        // "live_activity" command must route successfully (not throw unknownCommand)
        let liveActivityPayload: [AnyHashable: Any] = [
            "homeassistant": [
                "command": "live_activity",
                "tag": "test",
                "title": "Test",
                "message": "Hello",
            ] as [String: Any],
        ]
        XCTAssertNoThrow(try hang(manager.handle(liveActivityPayload)))

        // "end_live_activity" command must route successfully
        let endPayload: [AnyHashable: Any] = [
            "homeassistant": [
                "command": "end_live_activity",
                "tag": "test",
            ] as [String: Any],
        ]
        XCTAssertNoThrow(try hang(manager.handle(endPayload)))
    }

    /// The `live_update: true` data flag must be recognized (same field as Android Live Updates).
    func testLiveUpdateDataFlag_isRecognized() {
        let manager = NotificationCommandManager()
        let payload: [AnyHashable: Any] = [
            "homeassistant": [
                "live_update": true,
                "tag": "test",
                "title": "Test",
                "message": "Hello",
            ] as [String: Any],
        ]
        XCTAssertNoThrow(try hang(manager.handle(payload)))
    }
}
#endif
