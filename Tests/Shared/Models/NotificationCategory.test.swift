import Foundation
import GRDB
@testable import Shared
import UserNotifications
import XCTest

class NotificationCategoryTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try NotificationCategoryTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }
    }

    override func tearDown() {
        Current.database = previousDatabase

        super.tearDown()
    }

    // MARK: - NotificationAction

    func testActionOptions() {
        var action = NotificationAction()
        XCTAssertEqual(action.options, [])

        action.authenticationRequired = true
        XCTAssertEqual(action.options, [.authenticationRequired])

        action.destructive = true
        XCTAssertEqual(action.options, [.authenticationRequired, .destructive])

        action.foreground = true
        XCTAssertEqual(action.options, [.authenticationRequired, .destructive, .foreground])
    }

    func testActionBuildsPlainNotificationAction() {
        let action = NotificationAction(
            identifier: "OPEN",
            title: "Open",
            foreground: true
        )

        let unAction = action.action
        XCTAssertFalse(unAction is UNTextInputNotificationAction)
        XCTAssertEqual(unAction.identifier, "OPEN")
        XCTAssertEqual(unAction.title, "Open")
        XCTAssertEqual(unAction.options, [.foreground])
    }

    func testActionBuildsTextInputNotificationAction() {
        let action = NotificationAction(
            identifier: "REPLY",
            title: "Reply",
            textInput: true,
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Message"
        )

        guard let unAction = action.action as? UNTextInputNotificationAction else {
            XCTFail("expected a text input action")
            return
        }
        XCTAssertEqual(unAction.identifier, "REPLY")
        XCTAssertEqual(unAction.textInputButtonTitle, "Send")
        XCTAssertEqual(unAction.textInputPlaceholder, "Message")
    }

    func testActionFromServerConfig() throws {
        let source = try MobileAppConfigPushCategory.Action(JSON: [
            "title": "Do It",
            "identifier": "do_it",
            "authenticationRequired": true,
            "activationMode": "Foreground",
            "destructive": true,
            "behavior": "TextInput",
            "textInputButtonTitle": "Go",
            "textInputPlaceholder": "Value",
            "icon": "sfsymbols:house",
        ])

        let action = NotificationAction(action: source)
        XCTAssertEqual(action.identifier, "do_it")
        XCTAssertEqual(action.title, "Do It")
        XCTAssertTrue(action.isServerControlled)
        XCTAssertTrue(action.authenticationRequired)
        XCTAssertTrue(action.foreground)
        XCTAssertTrue(action.destructive)
        XCTAssertTrue(action.textInput)
        XCTAssertEqual(action.textInputButtonTitle, "Go")
        XCTAssertEqual(action.textInputPlaceholder, "Value")
        XCTAssertEqual(action.icon, "sfsymbols:house")
    }

    func testActionFromServerConfigDefaults() throws {
        let source = try MobileAppConfigPushCategory.Action(JSON: [
            "title": "Simple",
            "identifier": "simple",
        ])

        let action = NotificationAction(action: source)
        XCTAssertFalse(action.foreground)
        XCTAssertFalse(action.destructive)
        XCTAssertFalse(action.textInput)
        XCTAssertFalse(action.authenticationRequired)
        // falls back to the localized defaults rather than empty strings
        XCTAssertFalse(action.textInputButtonTitle.isEmpty)
        XCTAssertFalse(action.textInputPlaceholder.isEmpty)
    }

    // MARK: - NotificationCategory

    func testCategoryOptions() {
        var category = NotificationCategory(identifier: "TEST")
        XCTAssertEqual(category.options, [.customDismissAction])

        category.sendDismissActions = false
        XCTAssertEqual(category.options, [])

        category.hiddenPreviewsShowTitle = true
        category.hiddenPreviewsShowSubtitle = true
        XCTAssertEqual(category.options, [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle])
    }

    func testCategoryBuildsUNNotificationCategory() throws {
        let category = NotificationCategory(
            identifier: "lower_case",
            name: "Lower Case",
            hiddenPreviewsBodyPlaceholder: "%u notifications",
            categorySummaryFormat: "%u more",
            actions: [
                NotificationAction(identifier: "ONE", title: "One"),
                NotificationAction(identifier: "TWO", title: "Two"),
            ]
        )

        let unCategory = try XCTUnwrap(category.categories.first)
        XCTAssertEqual(category.categories.count, 1)
        // registered identifiers are uppercased to match incoming payloads
        XCTAssertEqual(unCategory.identifier, "LOWER_CASE")
        XCTAssertEqual(unCategory.actions.map(\.identifier), ["ONE", "TWO"])
        XCTAssertEqual(unCategory.hiddenPreviewsBodyPlaceholder, "%u notifications")
        XCTAssertEqual(unCategory.categorySummaryFormat, "%u more")
    }

    func testExampleServiceCall() {
        let category = NotificationCategory(
            identifier: "alarm",
            name: "Alarm",
            actions: [
                NotificationAction(identifier: "SNOOZE", title: "Snooze"),
            ]
        )

        let example = category.exampleServiceCall
        XCTAssertTrue(example.contains("category: ALARM"))
        XCTAssertTrue(example.contains("\"SNOOZE\": \"http://example.com/url\""))
        XCTAssertTrue(example.contains("\"\(NotificationCategory.FallbackActionIdentifier)\""))
    }

    func testDatabaseRoundTrip() throws {
        let category = NotificationCategory(
            identifier: "ROUND_TRIP",
            serverIdentifier: "server1",
            name: "Round Trip",
            isServerControlled: false,
            hiddenPreviewsBodyPlaceholder: "placeholder",
            categorySummaryFormat: "%u",
            sendDismissActions: false,
            hiddenPreviewsShowTitle: true,
            hiddenPreviewsShowSubtitle: false,
            actions: [
                NotificationAction(
                    identifier: "REPLY",
                    title: "Reply",
                    textInput: true,
                    icon: "sfsymbols:bell",
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Message"
                ),
            ]
        )

        category.save()

        let fetched = try XCTUnwrap(NotificationCategory.fetch(identifier: "ROUND_TRIP"))
        XCTAssertEqual(fetched, category)
        XCTAssertEqual(fetched.actions.count, 1)
        XCTAssertEqual(fetched.actions.first?.icon, "sfsymbols:bell")
    }

    func testDeleteIdentifiers() throws {
        NotificationCategory(identifier: "KEEP", name: "Keep").save()
        NotificationCategory(identifier: "REMOVE", name: "Remove").save()

        NotificationCategory.delete(identifiers: ["REMOVE"])

        XCTAssertEqual(NotificationCategory.all().map(\.identifier), ["KEEP"])
    }

    func testUpdateWithServerCategory() throws {
        let server = Server.fake(identifier: "server1")
        let source = try MobileAppConfigPushCategory(JSON: [
            "name": "Alarm",
            "identifier": "alarm",
            "actions": [
                ["title": "Snooze", "identifier": "snooze"],
                ["title": "Dismiss", "identifier": "dismiss", "destructive": true],
            ],
        ])

        var category = NotificationCategory(
            identifier: NotificationCategory.primaryKey(
                sourceIdentifier: source.primaryKey,
                serverIdentifier: server.identifier.rawValue
            ),
            serverIdentifier: server.identifier.rawValue
        )

        XCTAssertTrue(category.update(with: source, server: server))
        XCTAssertEqual(category.identifier, "ALARM")
        XCTAssertEqual(category.name, "Alarm")
        XCTAssertTrue(category.isServerControlled)
        XCTAssertEqual(category.serverIdentifier, "server1")
        XCTAssertEqual(category.actions.map(\.identifier), ["snooze", "dismiss"])
        XCTAssertEqual(category.actions.map(\.destructive), [false, true])
        XCTAssertTrue(category.actions.allSatisfy(\.isServerControlled))
    }
}
