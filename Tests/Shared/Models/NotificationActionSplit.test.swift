@testable import Shared
import UserNotifications
import XCTest

final class NotificationActionSplitTests: XCTestCase {
    private func action(
        _ identifier: String,
        textInput: Bool = false,
        authenticationRequired: Bool = false
    ) -> NotificationAction {
        NotificationAction(
            identifier: identifier,
            title: identifier.capitalized,
            textInput: textInput,
            authenticationRequired: authenticationRequired
        )
    }

    func testEmptyPayloadSplitsIntoNothing() {
        let split = NotificationActionSplit(payloadActions: [])

        XCTAssertTrue(split.systemHandled.isEmpty)
        XCTAssertTrue(split.appHandled.isEmpty)
    }

    func testPlainActionsStayWithTheSystem() {
        let split = NotificationActionSplit(payloadActions: [action("OPEN"), action("CANCEL")])

        XCTAssertEqual(split.systemHandled.map(\.identifier), ["OPEN", "CANCEL"])
        XCTAssertTrue(split.appHandled.isEmpty)
    }

    func testTextInputActionsAreHandledByTheApp() {
        let split = NotificationActionSplit(payloadActions: [action("REPLY", textInput: true)])

        XCTAssertTrue(split.systemHandled.isEmpty)
        XCTAssertEqual(split.appHandled.map(\.identifier), ["REPLY"])
    }

    func testMixedPayloadSplitsAndKeepsPayloadOrder() {
        let split = NotificationActionSplit(payloadActions: [
            action("OPEN"),
            action("REPLY", textInput: true),
            action("CANCEL"),
            action("COMMENT", textInput: true),
        ])

        XCTAssertEqual(split.systemHandled.map(\.identifier), ["OPEN", "CANCEL"])
        XCTAssertEqual(split.appHandled.map(\.identifier), ["REPLY", "COMMENT"])
    }

    /// The app cannot reproduce `.authenticationRequired`, so such an action has to keep going
    /// through the system even though its reply is the one watchOS drops.
    func testAuthenticationRequiredTextInputStaysWithTheSystem() {
        let split = NotificationActionSplit(payloadActions: [
            action("REPLY", textInput: true, authenticationRequired: true),
            action("COMMENT", textInput: true),
        ])

        XCTAssertEqual(split.systemHandled.map(\.identifier), ["REPLY"])
        XCTAssertEqual(split.appHandled.map(\.identifier), ["COMMENT"])
    }

    func testEveryActionIsAccountedForExactlyOnce() {
        let payloadActions = [
            action("OPEN"),
            action("REPLY", textInput: true),
            action("SECURE", textInput: true, authenticationRequired: true),
            action("LOCKED", authenticationRequired: true),
        ]

        let split = NotificationActionSplit(payloadActions: payloadActions)

        XCTAssertEqual(split.systemHandled.count + split.appHandled.count, payloadActions.count)
        let overlap = Set(split.systemHandled.map(\.identifier))
            .intersection(split.appHandled.map(\.identifier))
        XCTAssertTrue(overlap.isEmpty)
    }

    func testSplitsFromNotificationContentPayload() {
        let content = UNMutableNotificationContent()
        content.userInfo = ["actions": [
            ["identifier": "OPEN", "title": "Open"],
            ["identifier": "REPLY", "title": "Reply", "behavior": "textInput"],
        ]]

        let split = NotificationActionSplit(payloadActions: content.userInfoPayloadActions)

        XCTAssertEqual(split.systemHandled.map(\.identifier), ["OPEN"])
        XCTAssertEqual(split.appHandled.map(\.identifier), ["REPLY"])
    }
}
