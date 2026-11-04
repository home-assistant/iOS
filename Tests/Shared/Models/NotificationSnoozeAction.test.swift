@testable import Shared
import UserNotifications
import XCTest

final class NotificationSnoozeActionTests: XCTestCase {
    func testMinutesParsedFromActionIdentifier() {
        XCTAssertEqual(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_5"), 5)
        XCTAssertEqual(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_90"), 90)
    }

    func testMinutesRoundTripsThroughActionIdentifier() {
        let action = NotificationSnoozeAction(minutes: 15, sortOrder: 0)
        XCTAssertEqual(NotificationSnoozeAction.minutes(fromActionIdentifier: action.actionIdentifier), 15)
    }

    func testMinutesNilForNonSnoozeIdentifiers() {
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: "SNOOZE_5"))
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_"))
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_abc"))
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: UNNotificationDefaultActionIdentifier))
    }

    func testMinutesNilForNonPositiveDurations() {
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_0"))
        XCTAssertNil(NotificationSnoozeAction.minutes(fromActionIdentifier: "HA_SNOOZE_-5"))
    }
}
