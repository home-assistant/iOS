import Foundation
@testable import Shared
import UserNotifications
import XCTest

final class NotificationActionExampleTriggerTests: XCTestCase {
    func testExampleTriggerWithCategoryAndTextInput() {
        let api = HomeAssistantAPI(server: .fake())

        let example = NotificationAction.exampleTrigger(
            api: api,
            identifier: "REPLY",
            category: "MESSAGES",
            textInput: true
        )

        XCTAssertTrue(example.hasPrefix("- platform: event\n"))
        XCTAssertTrue(example.contains("event_type: ios.notification_action_fired"))
        XCTAssertTrue(example.contains("actionName: REPLY"))
        XCTAssertTrue(example.contains("categoryName: MESSAGES"))
        XCTAssertTrue(example.contains("action_data: # value of action_data in notify call"))
        XCTAssertTrue(example.contains("textInput: # text you input"))
        XCTAssertTrue(example.contains("response_info: # text you input"))
    }

    func testExampleTriggerWithoutCategoryOrTextInput() {
        let api = HomeAssistantAPI(server: .fake())

        let example = NotificationAction.exampleTrigger(
            api: api,
            identifier: "OPEN",
            category: nil,
            textInput: false
        )

        XCTAssertTrue(example.contains("actionName: OPEN"))
        XCTAssertFalse(example.contains("categoryName"))
        XCTAssertFalse(example.contains("textInput"))
        XCTAssertFalse(example.contains("response_info"))
    }

    func testExampleTriggerSortsEventData() throws {
        let api = HomeAssistantAPI(server: .fake())

        let example = NotificationAction.exampleTrigger(
            api: api,
            identifier: "OPEN",
            category: "CAT",
            textInput: true
        )

        let dataLines = example
            .components(separatedBy: "\n")
            .drop(while: { !$0.contains("event_data:") })
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertFalse(dataLines.isEmpty)
        XCTAssertEqual(dataLines, dataLines.sorted())
    }

    func testSFSymbolIconIsAttachedToAction() {
        let symbol = NotificationAction(identifier: "BELL", title: "Bell", icon: "sfsymbols:bell")
        XCTAssertNotNil(symbol.action.icon)

        let textInputSymbol = NotificationAction(
            identifier: "REPLY",
            title: "Reply",
            textInput: true,
            icon: "sfsymbols:text.bubble"
        )
        XCTAssertTrue(textInputSymbol.action is UNTextInputNotificationAction)
        XCTAssertNotNil(textInputSymbol.action.icon)

        let nonSymbol = NotificationAction(identifier: "BELL", title: "Bell", icon: "mdi:bell")
        XCTAssertNil(nonSymbol.action.icon)
    }

    func testDefaultTextInputTitlesAreLocalized() {
        let action = NotificationAction()

        XCTAssertEqual(
            action.textInputButtonTitle,
            L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
        )
        XCTAssertEqual(
            action.textInputPlaceholder,
            L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
        )
    }
}
