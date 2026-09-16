import ObjectMapper
@testable import Shared
import UserNotifications
import XCTest

final class PushActionInfoTests: XCTestCase {
    private func content(
        category: String,
        userInfo: [AnyHashable: Any] = [:]
    ) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = category
        content.userInfo = userInfo
        return content
    }

    func testBuildsFromContentAndTextInput() {
        let info = HomeAssistantAPI.PushActionInfo(
            content: content(category: "DYNAMIC", userInfo: ["homeassistant": ["foo": "bar"]]),
            actionIdentifier: "REPLY",
            textInput: "on my way"
        )

        XCTAssertEqual(info.identifier, "REPLY")
        XCTAssertEqual(info.category, "DYNAMIC")
        XCTAssertEqual(info.textInput, "on my way")
        XCTAssertEqual(info.actionData as? [String: String], ["foo": "bar"])
    }

    func testUncombinesDuplicatedActionIdentifier() {
        let info = HomeAssistantAPI.PushActionInfo(
            content: content(category: "DYNAMIC"),
            actionIdentifier: UNNotificationContent.combinedAction(base: "REPLY", appended: "2"),
            textInput: nil
        )

        XCTAssertEqual(info.identifier, "REPLY")
        XCTAssertNil(info.textInput)
    }

    /// The watch sends this over WatchConnectivity for the phone to fire, so the reply has to
    /// survive the ObjectMapper round trip.
    func testTextInputSurvivesMappingRoundTrip() throws {
        let info = HomeAssistantAPI.PushActionInfo(
            content: content(category: "DYNAMIC"),
            actionIdentifier: "REPLY",
            textInput: "be right there"
        )

        let restored = try XCTUnwrap(Mapper<HomeAssistantAPI.PushActionInfo>().map(JSON: info.toJSON()))

        XCTAssertEqual(restored.identifier, "REPLY")
        XCTAssertEqual(restored.category, "DYNAMIC")
        XCTAssertEqual(restored.textInput, "be right there")
    }

    func testEventsCarryTheReplyText() {
        let api = HomeAssistantAPI(server: .fake())
        let mobileApp = api.mobileAppNotificationActionEvent(
            identifier: "REPLY",
            category: "DYNAMIC",
            actionData: nil,
            textInput: "on my way"
        )
        let legacy = api.legacyNotificationActionEvent(
            identifier: "REPLY",
            category: "DYNAMIC",
            actionData: nil,
            textInput: "on my way"
        )

        XCTAssertEqual(mobileApp.eventType, "mobile_app_notification_action")
        XCTAssertEqual(mobileApp.eventData["reply_text"] as? String, "on my way")
        XCTAssertEqual(legacy.eventType, "ios.notification_action_fired")
        XCTAssertEqual(legacy.eventData["textInput"] as? String, "on my way")
        XCTAssertEqual(legacy.eventData["response_info"] as? String, "on my way")
    }
}
