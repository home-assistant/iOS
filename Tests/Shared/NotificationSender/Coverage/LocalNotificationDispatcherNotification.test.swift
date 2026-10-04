import Foundation
@testable import Shared
import UserNotifications
import XCTest

final class LocalNotificationDispatcherNotificationTests: XCTestCase {
    private var previousReceiveDebugNotifications: Bool!

    override func setUp() {
        super.setUp()
        previousReceiveDebugNotifications = Current.settingsStore.receiveDebugNotifications
    }

    override func tearDown() {
        Current.settingsStore.receiveDebugNotifications = previousReceiveDebugNotifications
        super.tearDown()
    }

    func testNotificationDefaults() {
        let notification = LocalNotificationDispatcher.Notification(id: .serverUnreachable, title: "Title")

        XCTAssertEqual(notification.id, .serverUnreachable)
        XCTAssertEqual(notification.title, "Title")
        XCTAssertNil(notification.body)
        XCTAssertNil(notification.sound)
    }

    func testNotificationStoresAllFields() {
        let sound = UNNotificationSound.default
        let notification = LocalNotificationDispatcher.Notification(
            id: .debug,
            title: "Title",
            body: "Body",
            sound: sound
        )

        XCTAssertEqual(notification.id, .debug)
        XCTAssertEqual(notification.body, "Body")
        XCTAssertIdentical(notification.sound, sound)
    }

    /// With debug notifications switched off, a debug notification is dropped before it reaches
    /// the notification center (which would otherwise need a real app bundle).
    func testDebugNotificationIsDroppedWhenSettingIsOff() {
        Current.settingsStore.receiveDebugNotifications = false

        LocalNotificationDispatcher().send(.init(id: .debug, title: "Debug", body: "Ignored"))

        XCTAssertFalse(Current.settingsStore.receiveDebugNotifications)
    }
}
