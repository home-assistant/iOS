import PromiseKit
@testable import Shared
import UserNotifications
import XCTest

class ClientEventTests: XCTestCase {
    var store: ClientEventStore!
    private var previousDate: (() -> Date)!
    /// A file of this test's own: the app group's `clientEvents.json` is shared with every other test
    /// process on the simulator (parallel workers, the app's tests), which write and clear it concurrently.
    private var eventsFile: URL!

    override func setUp() {
        super.setUp()
        previousDate = Current.date
        eventsFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClientEventTests-\(UUID().uuidString).json")
        store = ClientEventStore(fileURL: eventsFile)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: eventsFile)
        store = nil
        eventsFile = nil
        Current.date = previousDate
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

    func testReadsFileWrittenAsSingleJSONArray() throws {
        let event = ClientEvent(text: "Legacy", type: .notification)
        try JSONEncoder().encode([event]).write(to: eventsFile, options: .atomic)

        let retrieved = store.getEvents()
        XCTAssertEqual(1, retrieved.count)
        XCTAssertEqual("Legacy", retrieved.first?.text)
    }

    func testKeepsEventsAcrossAppends() throws {
        store.addEvent(ClientEvent(text: "First", type: .notification))
        store.addEvent(ClientEvent(text: "Second", type: .notification))

        XCTAssertEqual(["First", "Second"], store.getEvents().map(\.text))
    }

    func testCanClearEvents() throws {
        let event = ClientEvent(text: "Yo", type: .notification)
        store.addEvent(event)
        XCTAssertEqual(1, store.getEvents().count)
        store.clearAllEvents()
        XCTAssertEqual(0, store.getEvents().count)
    }
}
