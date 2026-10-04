import Foundation
import ObjectMapper
@testable import Shared
import XCTest

final class MobileAppConfigTests: XCTestCase {
    func testDefaultInitHasNoCategories() {
        XCTAssertTrue(MobileAppConfig().push.categories.isEmpty)
        XCTAssertTrue(MobileAppConfigPush().categories.isEmpty)
    }

    func testMissingPushFallsBackToEmpty() throws {
        let config = try MobileAppConfig(JSON: [:])
        XCTAssertTrue(config.push.categories.isEmpty)
    }

    func testMissingCategoriesFallsBackToEmpty() throws {
        let config = try MobileAppConfig(JSON: ["push": [String: Any]()])
        XCTAssertTrue(config.push.categories.isEmpty)
    }

    func testMapsPushCategories() throws {
        let config = try MobileAppConfig(JSON: [
            "push": [
                "categories": [
                    [
                        "name": "Alarm",
                        "identifier": "alarm",
                        "actions": [
                            ["title": "Snooze", "identifier": "SNOOZE"],
                        ],
                    ],
                    [
                        "name": "Door",
                    ],
                ],
            ],
        ])

        XCTAssertEqual(config.push.categories.map(\.name), ["Alarm", "Door"])
        XCTAssertEqual(config.push.categories.map(\.identifier), ["alarm", "Door"])
        XCTAssertEqual(config.push.categories.map(\.primaryKey), ["ALARM", "DOOR"])
        XCTAssertEqual(config.push.categories.first?.actions.map(\.identifier), ["SNOOZE"])
        XCTAssertEqual(config.push.categories.last?.actions.count, 0)
    }

    func testActionDefaults() throws {
        let action = try MobileAppConfigPushCategory.Action(JSON: [:])

        XCTAssertEqual(action.title, "Missing title")
        XCTAssertEqual(action.identifier, "missing")
        XCTAssertFalse(action.authenticationRequired)
        XCTAssertEqual(action.behavior, "default")
        XCTAssertEqual(action.activationMode, "background")
        XCTAssertFalse(action.destructive)
        XCTAssertNil(action.textInputButtonTitle)
        XCTAssertNil(action.textInputPlaceholder)
        XCTAssertNil(action.url)
        XCTAssertNil(action.icon)
    }

    func testActionFallsBackToAndroidActionKey() throws {
        let action = try MobileAppConfigPushCategory.Action(JSON: ["action": "OPEN_GARAGE", "title": "Open"])

        XCTAssertEqual(action.identifier, "OPEN_GARAGE")
        XCTAssertEqual(action.title, "Open")
    }

    func testActionWithURLActivatesInForeground() throws {
        let url = try MobileAppConfigPushCategory.Action(JSON: [
            "identifier": "OPEN",
            "url": "/lovelace/cameras",
        ])
        XCTAssertEqual(url.url, "/lovelace/cameras")
        XCTAssertEqual(url.activationMode, "foreground")

        let uri = try MobileAppConfigPushCategory.Action(JSON: [
            "identifier": "OPEN",
            "activationMode": "background",
            "uri": "https://example.com",
        ])
        XCTAssertEqual(uri.url, "https://example.com")
        XCTAssertEqual(uri.activationMode, "foreground")
    }

    func testReplyActionBecomesTextInput() throws {
        let action = try MobileAppConfigPushCategory.Action(JSON: ["identifier": "Reply", "behavior": "default"])

        XCTAssertEqual(action.behavior, "textinput")
    }

    func testCategoryRequiresName() {
        XCTAssertThrowsError(try MobileAppConfigPushCategory(JSON: ["identifier": "nameless"]))
    }
}
