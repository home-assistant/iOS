import PromiseKit
import RealmSwift
@testable import Shared
import UserNotifications
import XCTest

class ClientEventTests: XCTestCase {
    var store: ClientEventStore!
    override func setUp() {
        super.setUp()
        store = ClientEventStore()
    }

    override func tearDown() {
        store.clearAllEvents()
		super.tearDown()
    }

    func testStartsEmpty() {
        XCTAssertEqual(0, store.getEvents().count)
    }

    func testNotificationTitleForNotificationWithoutTitle() {
        let mutableContent = UNMutableNotificationContent()
        let alert = "House mode changed to away"
        let expectedTitle = "Received a Push Notification: \(alert)"
        mutableContent.userInfo = ["aps": ["alert": alert, "sound": "default:"]]
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testNotificationTitleForNotificationWithATitle() {
        let mutableContent = UNMutableNotificationContent()
        let alert = "House mode changed to away"
        mutableContent.title = "Home Assistant Notification"
        mutableContent.subtitle = "Fake Sub"
        mutableContent.userInfo = ["aps": ["alert": alert, "sound": "default:"]]

        let expectedTitle = "Received a Push Notification: \(mutableContent.title) - \(mutableContent.subtitle)"
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testUnknownNotification() {
        let mutableContent = UNMutableNotificationContent()
        mutableContent.userInfo = ["aps": ["sound": "default:"]]

        let expectedTitle = "Received a Push Notification: "
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testCanWriteClientEvent() throws {
        let event = ClientEvent(text: "Yo", type: .notification)
        store.addEvent(event)
        XCTAssertEqual(1, store.getEvents().count)
    }

    func testEventWrittenCorrectly() throws {
        let date = Date()
        Current.date = { date }
        let event = ClientEvent(text: "Yo", type: .notification)
        store.addEvent(event)
        let retrieved = store.getEvents().first
        XCTAssertEqual(retrieved?.text, "Yo")
        XCTAssertEqual(retrieved?.type, .notification)
        XCTAssertEqual(retrieved?.date.ISO8601Format(), date.ISO8601Format())
    }

    func testCanClearEvents() throws {
        let event = ClientEvent(text: "Yo", type: .notification)
        store.addEvent(event)
        XCTAssertEqual(1, store.getEvents().count)
        store.clearAllEvents()
        XCTAssertEqual(0, store.getEvents().count)
    }
}
