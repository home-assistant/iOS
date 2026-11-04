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

    /// The relay stamps the start send-time as the snake_case `started_at` key (Unix epoch
    /// seconds). The registry compares it to keep the newest of duplicate push-to-starts, so the
    /// wire key and numeric epoch encoding must not drift.
    func testAttributes_startedAt_decodesFromEpochAndEncodesAsStartedAt() throws {
        let json = Data(#"{"tag":"t","title":"Title","started_at":1700000000}"#.utf8)
        let decoded = try JSONDecoder().decode(HALiveActivityAttributes.self, from: json)
        XCTAssertEqual(decoded.startedAt, 1_700_000_000)

        let data = try JSONEncoder().encode(decoded)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["started_at"] as? Double, 1_700_000_000)
        XCTAssertNil(dict["startedAt"], "must use the snake_case wire key")
    }

    /// Activities started before this shipped (or by a relay that omits it) must still decode,
    /// with a nil `startedAt` — which the registry treats as oldest. The field stays optional.
    func testAttributes_missingStartedAt_decodesAsNil() throws {
        let json = Data(#"{"tag":"t","title":"Title"}"#.utf8)
        let decoded = try JSONDecoder().decode(HALiveActivityAttributes.self, from: json)
        XCTAssertNil(decoded.startedAt)
    }

    func testAttributes_missingOrEmptyTitle_decodesAsDefault() throws {
        let missing = try JSONDecoder().decode(
            HALiveActivityAttributes.self,
            from: Data(#"{"tag":"t"}"#.utf8)
        )
        XCTAssertEqual(missing.title, HALiveActivityAttributes.defaultTitle)
        XCTAssertEqual(missing.tag, "t")

        let empty = try JSONDecoder().decode(
            HALiveActivityAttributes.self,
            from: Data(#"{"tag":"t","title":""}"#.utf8)
        )
        XCTAssertEqual(empty.title, HALiveActivityAttributes.defaultTitle)
    }

    func testContentState_emptyOrMissingTitle_decodesAsNil() throws {
        let empty = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","title":""}"#.utf8)
        )
        XCTAssertNil(empty.title)

        let missing = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m"}"#.utf8)
        )
        XCTAssertNil(missing.title)
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
            chronometerStart: Date(timeIntervalSince1970: 0),
            icon: "mdi:test",
            color: "#FF0000",
            url: "/lovelace/0",
            backgroundColor: "#000000",
            textColor: "#FFFFFF",
            progressBarColor: "#FF9800",
            progressBarDirection: "decreasing"
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
            "chronometer_start",
            "icon",
            "color",
            "url",
            "background_color",
            "text_color",
            "progress_bar_color",
            "progress_bar_direction",
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
            chronometerStart: Date(timeIntervalSince1970: 1_699_998_800),
            icon: "mdi:washing-machine",
            color: "#2196F3",
            url: "/lovelace/laundry",
            backgroundColor: "#101820",
            textColor: "#FFFFFF",
            progressBarColor: "#FF9800",
            progressBarDirection: "decreasing"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(HALiveActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    /// HA sends `progress`/`progress_max` as JSON numbers that may be fractional (e.g. 20.1234).
    /// ActivityKit decodes content-state OS-side with a strict JSONDecoder, so a float must not make
    /// the decode throw — that would silently drop the remote update (stale activity) or reject a
    /// push-to-start. It must decode, rounded to the nearest Int.
    func testContentState_progressAsFloat_decodesRounded() throws {
        let decoded = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress":20.1234,"progress_max":100}"#.utf8)
        )
        XCTAssertEqual(decoded.progress, 20)
        XCTAssertEqual(decoded.progressMax, 100)

        let rounding = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress":20.6}"#.utf8)
        )
        XCTAssertEqual(rounding.progress, 21)
    }

    /// `progress_bar_direction` is stored as the raw wire string; an unrecognised value must
    /// decode without throwing (a throw would drop the whole OS-side update) and resolve to nil
    /// so rendering falls back to the default direction.
    func testContentState_progressBarDirection_decodesLeniently() throws {
        let decreasing = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress_bar_direction":"decreasing"}"#.utf8)
        )
        XCTAssertEqual(decreasing.resolvedProgressBarDirection, .decreasing)

        // Case-insensitive: Android-style automations may send capitalised values.
        let uppercase = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress_bar_direction":"Increasing"}"#.utf8)
        )
        XCTAssertEqual(uppercase.resolvedProgressBarDirection, .increasing)

        let unknown = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress_bar_direction":"sideways"}"#.utf8)
        )
        XCTAssertEqual(unknown.progressBarDirection, "sideways")
        XCTAssertNil(unknown.resolvedProgressBarDirection)

        let missing = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m"}"#.utf8)
        )
        XCTAssertNil(missing.progressBarDirection)
        XCTAssertNil(missing.resolvedProgressBarDirection)
    }

    /// `decreasing` flips only the visual fill: the bar shows what remains while
    /// `progressFraction` (used by percent labels) keeps reporting the raw progress.
    func testContentState_progressBarFillFraction_honorsDirection() {
        let base = HALiveActivityAttributes.ContentState(
            message: "m",
            progress: 30,
            progressMax: 100
        )
        XCTAssertEqual(base.progressBarFillFraction ?? -1, 0.3, accuracy: 0.0001)

        var decreasing = base
        decreasing.progressBarDirection = "decreasing"
        XCTAssertEqual(decreasing.progressBarFillFraction ?? -1, 0.7, accuracy: 0.0001)
        XCTAssertEqual(decreasing.progressFraction ?? -1, 0.3, accuracy: 0.0001)

        var unknown = base
        unknown.progressBarDirection = "sideways"
        XCTAssertEqual(unknown.progressBarFillFraction ?? -1, 0.3, accuracy: 0.0001)

        var noProgress = base
        noProgress.progress = nil
        noProgress.progressBarDirection = "decreasing"
        XCTAssertNil(noProgress.progressBarFillFraction)
    }

    /// A content-state payload without progress keys still decodes, with nil progress.
    func testContentState_missingProgress_decodesAsNil() throws {
        let decoded = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m"}"#.utf8)
        )
        XCTAssertNil(decoded.progress)
        XCTAssertNil(decoded.progressMax)
    }

    /// An out-of-Int-range progress value must degrade to nil rather than trap the OS-side decoder.
    func testContentState_progressOutOfIntRange_decodesAsNil() throws {
        let decoded = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(#"{"message":"m","progress":1e19,"progress_max":100}"#.utf8)
        )
        XCTAssertNil(decoded.progress)
        XCTAssertEqual(decoded.progressMax, 100)
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
