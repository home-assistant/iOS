@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@Suite(.serialized)
struct NotificationHistoryViewTests {
    @MainActor
    @Test func testUI() async throws {
        let previousStore = Current.notificationHistoryStore
        defer { Current.notificationHistoryStore = previousStore }

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        Current.notificationHistoryStore = FakeNotificationHistoryStore(entries: [
            NotificationHistoryEntry(
                id: "1",
                date: date,
                kind: .remote,
                title: "Front Door",
                body: "Motion detected",
                payloadJSON: "{\n  \"tag\" : \"front_door\"\n}"
            ),
            NotificationHistoryEntry(
                id: "2",
                date: date.addingTimeInterval(-60),
                kind: .local,
                title: "Doorbell",
                body: "Someone is at the door"
            ),
            NotificationHistoryEntry(
                id: "3",
                date: date.addingTimeInterval(-120),
                kind: .liveActivityLocal,
                title: "Laundry",
                body: "20 minutes remaining"
            ),
        ])

        assertLightDarkSnapshots(of: NavigationView { NotificationHistoryView() }, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testDetailUI() async throws {
        let entry = NotificationHistoryEntry(
            id: "detail",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .remote,
            title: "Front Door",
            body: "Motion detected",
            payloadJSON: """
            {
              "aps" : {
                "alert" : {
                  "body" : "Motion detected",
                  "title" : "Front Door"
                },
                "mutable-content" : 1
              },
              "entity_id" : "binary_sensor.front_door",
              "presentation_options" : [
                "alert",
                "sound"
              ]
            }
            """
        )

        assertLightDarkSnapshots(
            of: NavigationView { NotificationHistoryDetailView(entry: entry) },
            drawHierarchyInKeyWindow: true
        )
    }
}

private final class FakeNotificationHistoryStore: NotificationHistoryStoreProtocol {
    private var entries: [NotificationHistoryEntry]

    init(entries: [NotificationHistoryEntry]) {
        self.entries = entries
    }

    func record(_ entry: NotificationHistoryEntry) {
        entries.append(entry)
    }

    func getEntries() -> [NotificationHistoryEntry] {
        entries
    }

    func clearAllEntries() {
        entries = []
    }
}
