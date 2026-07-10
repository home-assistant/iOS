@testable import Shared
import UserNotifications
import XCTest

class NotificationHistoryStoreTests: XCTestCase {
    var store: NotificationHistoryStore!

    override func setUp() {
        super.setUp()
        store = NotificationHistoryStore()
        store.clearAllEntries()
    }

    override func tearDown() {
        store.clearAllEntries()
        super.tearDown()
    }

    func testStartsEmpty() {
        XCTAssertEqual(0, store.getEntries().count)
    }

    func testRecordsEntry() {
        store.record(NotificationHistoryEntry(kind: .remote, title: "Hello", body: "World"))
        let entries = store.getEntries()
        XCTAssertEqual(1, entries.count)
        XCTAssertEqual(entries.first?.kind, .remote)
        XCTAssertEqual(entries.first?.title, "Hello")
        XCTAssertEqual(entries.first?.body, "World")
    }

    func testRecordsLiveActivityLocalKind() {
        store.record(NotificationHistoryEntry(kind: .liveActivityLocal, title: "Laundry"))
        XCTAssertEqual(store.getEntries().first?.kind, .liveActivityLocal)
    }

    func testEntryWrittenCorrectly() {
        let previousDate = Current.date
        defer { Current.date = previousDate }
        let date = Date()
        Current.date = { date }
        store.record(NotificationHistoryEntry(kind: .local, title: "Yo"))
        let retrieved = store.getEntries().first
        XCTAssertEqual(retrieved?.title, "Yo")
        XCTAssertEqual(retrieved?.kind, .local)
        XCTAssertEqual(retrieved?.date.ISO8601Format(), date.ISO8601Format())
    }

    func testCanClearEntries() {
        store.record(NotificationHistoryEntry(kind: .local))
        XCTAssertTrue(store.getEntries().count != 0)
        store.clearAllEntries()
        XCTAssertEqual(0, store.getEntries().count)
    }

    func testCapsToLimitDroppingOldest() {
        let total = NotificationHistoryStore.entriesCacheLimit + 5
        for index in 0 ..< total {
            store.record(NotificationHistoryEntry(id: "id-\(index)", kind: .remote, title: "n\(index)"))
        }
        let entries = store.getEntries()
        XCTAssertEqual(entries.count, NotificationHistoryStore.entriesCacheLimit)
        XCTAssertNil(entries.first { $0.id == "id-0" })
        XCTAssertNotNil(entries.first { $0.id == "id-\(total - 1)" })
    }

    func testInitFromContentExtractsFieldsAndRedactsConfirmID() {
        let content = UNMutableNotificationContent()
        content.title = "Title"
        content.subtitle = "Sub"
        content.body = "Body"
        content.userInfo = [
            "aps": ["alert": ["body": "Body"]],
            "hass_confirm_id": "secret-confirm-token",
            "tag": "abc",
            "homeassistant": ["webhook_id": "secret-nested-hook", "command": "show"],
        ]
        let entry = NotificationHistoryEntry(content: content, kind: .remote)
        XCTAssertEqual(entry.title, "Title")
        XCTAssertEqual(entry.subtitle, "Sub")
        XCTAssertEqual(entry.body, "Body")
        let payload = entry.payloadJSON ?? ""
        XCTAssertTrue(payload.contains("tag"))
        XCTAssertFalse(payload.contains("hass_confirm_id"))
        XCTAssertFalse(payload.contains("secret-confirm-token"))
        XCTAssertFalse(payload.contains("webhook_id"), "nested webhook_id must be redacted")
        XCTAssertFalse(payload.contains("secret-nested-hook"))
    }

    func testBodyFallsBackToApsAlertString() {
        let content = UNMutableNotificationContent()
        content.userInfo = ["aps": ["alert": "Hello world"]]
        let entry = NotificationHistoryEntry(content: content, kind: .remote)
        XCTAssertEqual(entry.body, "Hello world")
    }

    func testDisplayTitleFallsBackToBody() {
        let entry = NotificationHistoryEntry(kind: .local, title: nil, body: "Only body")
        XCTAssertEqual(entry.displayTitle, "Only body")
    }
}
