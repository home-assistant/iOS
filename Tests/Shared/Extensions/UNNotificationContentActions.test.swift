import Foundation
import GRDB
@testable import Shared
import UserNotifications
import XCTest

final class UNNotificationContentActionsTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try NotificationSnoozeActionTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }
    }

    override func tearDown() {
        Current.database = previousDatabase

        super.tearDown()
    }

    private func content(actions: [[String: Any]]?) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if let actions {
            content.userInfo = ["actions": actions]
        }
        return content
    }

    func testUsesSnoozeActionsWhenPayloadHasNoActions() {
        let actions = content(actions: nil).userInfoActions
        let identifiers = actions.map(\.identifier)

        XCTAssertTrue(identifiers.contains(NotificationSnoozeAction.actionIdentifierPrefix + "5"))
        XCTAssertTrue(identifiers.contains(NotificationSnoozeAction.actionIdentifierPrefix + "15"))
        XCTAssertTrue(identifiers.contains(NotificationSnoozeAction.actionIdentifierPrefix + "60"))
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix(NotificationSnoozeAction.actionIdentifierPrefix) })
    }

    func testIgnoresSnoozeActionsWhenPayloadDefinesActions() {
        XCTAssertFalse(NotificationSnoozeAction.enabledActions().isEmpty)

        let actions = content(actions: [
            ["identifier": "CANCEL", "title": "Cancel"],
        ]).userInfoActions

        XCTAssertEqual(actions.map(\.identifier), ["CANCEL"])
        XCTAssertFalse(actions.contains { $0.identifier.hasPrefix(NotificationSnoozeAction.actionIdentifierPrefix) })
    }

    func testKeepsPayloadActionOrderAndDropsSnooze() {
        let payloadActions = (0 ..< 3).map { index in
            ["identifier": "ACTION_\(index)", "title": "Action \(index)"]
        }

        let actions = content(actions: payloadActions).userInfoActions

        XCTAssertEqual(actions.map(\.identifier), ["ACTION_0", "ACTION_1", "ACTION_2"])
        XCTAssertFalse(actions.contains { $0.identifier.hasPrefix(NotificationSnoozeAction.actionIdentifierPrefix) })
    }

    func testCapsPayloadActionsAtMaximum() {
        let payloadActions = (0 ..< 15).map { index in
            ["identifier": "ACTION_\(index)", "title": "Action \(index)"]
        }

        let actions = content(actions: payloadActions).userInfoActions

        XCTAssertEqual(actions.count, 10)
    }
}
