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

    /// The originating server id is carried as the snake_case `webhook_id` key in the
    /// push-to-start `attributes`. The relay sends it so a tap can open that server.
    func testAttributes_serverWebhookId_encodesAsWebhookId() throws {
        let attributes = HALiveActivityAttributes(tag: "t", title: "Title", serverWebhookId: "wh-123")
        let data = try JSONEncoder().encode(attributes)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["webhook_id"] as? String, "wh-123")
        XCTAssertNil(dict["serverWebhookId"], "must use the snake_case wire key")
    }

    /// Activities created before this shipped (or by a relay that omits it) must still decode,
    /// with a nil server id — the field stays optional.
    func testAttributes_missingWebhookId_decodesAsNil() throws {
        let json = Data(#"{"tag":"t","title":"Title"}"#.utf8)
        let decoded = try JSONDecoder().decode(HALiveActivityAttributes.self, from: json)
        XCTAssertNil(decoded.serverWebhookId)
        XCTAssertEqual(decoded.tag, "t")
        XCTAssertEqual(decoded.title, "Title")
    }

    /// CodingKeys define the JSON field names in APNs content-state payloads.
    /// Adding new optional fields is safe; renaming or removing breaks in-flight activities.
    func testContentState_codingKeys_areFrozen() {
        let state = HALiveActivityAttributes.ContentState(
            message: "test",
            title: "Title",
            criticalText: "ct",
            progress: 1,
            progressMax: 2,
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 0),
            icon: "mdi:test",
            color: "#FF0000",
            url: "/lovelace/0",
            backgroundColor: "#000000",
            textColor: "#FFFFFF",
            progressBarColor: "#FF9800"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try! encoder.encode(state)
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        // These keys must match the Android notification field names exactly.
        let expectedKeys: Set<String> = [
            "title",
            "message",
            "critical_text",
            "progress",
            "progress_max",
            "chronometer",
            "countdown_end",
            "icon",
            "color",
            "url",
            "background_color",
            "text_color",
            "progress_bar_color",
        ]
        XCTAssertEqual(Set(dict.keys), expectedKeys)
    }

    /// ContentState must round-trip through JSON without data loss.
    func testContentState_roundTrip_preservesAllFields() {
        let original = HALiveActivityAttributes.ContentState(
            message: "Cycle in progress",
            title: "Washer",
            criticalText: "45 min",
            progress: 2700,
            progressMax: 3600,
            chronometer: true,
            countdownEnd: Date(timeIntervalSince1970: 1_700_000_000),
            icon: "mdi:washing-machine",
            color: "#2196F3",
            url: "/lovelace/laundry",
            backgroundColor: "#101820",
            textColor: "#FFFFFF",
            progressBarColor: "#FF9800"
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
            "live_activity_token"
        )
    }

    /// Registration app_data key for the push-to-start token.
    /// Must match what HA core stores for starts before a per-activity token exists.
    func testPushToStartRegistrationKey_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.pushToStartRegistrationKey,
            "start_live_activity_token"
        )
    }

    /// Webhook type string for reporting a new per-activity push token.
    /// Must match the HA core webhook handler name.
    func testWebhookTypeToken_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.webhookTypeToken,
            "live_activity_token"
        )
    }

    /// Keys in the token webhook request data dictionary.
    /// Must match what HA core's update_live_activity_token handler expects.
    func testTokenWebhookKeys_areFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.tokenWebhookKeys,
            ["tag", "push_token", "expires_at"]
        )
    }

    /// The iOS app owns the token expiry window it sends to HA core.
    func testTokenWebhookExpiry_isTwelveHours() {
        XCTAssertEqual(
            LiveActivityRegistry.pushTokenTimeToLive,
            12 * 60 * 60
        )
    }

    /// Registration app_data key for the start failsafe. Must match the key HA core reads to
    /// decide how long to wait for a per-activity token before allowing another start.
    func testStartFailsafeRegistrationKey_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.startFailsafeRegistrationKey,
            "live_activity_start_failsafe"
        )
    }

    /// The start failsafe the app reports to HA core, in seconds.
    func testStartSuppressionTimeToLive_isSixHours() {
        XCTAssertEqual(
            LiveActivityRegistry.startSuppressionTimeToLive,
            6 * 60 * 60
        )
    }

    /// Webhook type string for reporting a dismissed activity.
    /// Must match the HA core webhook handler name.
    func testWebhookTypeDismissed_isFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.webhookTypeDismissed,
            "live_activity_dismissed"
        )
    }

    /// Keys in the dismissed webhook request data dictionary.
    /// Must match what HA core's live_activity_dismissed handler expects.
    func testDismissedWebhookKeys_areFrozen() {
        XCTAssertEqual(
            LiveActivityRegistry.dismissedWebhookKeys,
            ["tag"]
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
