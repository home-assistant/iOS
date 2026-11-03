@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Shared state: the screen reads `Current.notificationHistoryStore` from SwiftUI callbacks on the
/// main run loop, outside the test's task, so it has to be swapped globally.
@Suite(.sharedState)
@MainActor
struct NotificationHistoryViewRenderTests {
    private static let entries: [NotificationHistoryEntry] = [
        .init(
            date: Date(timeIntervalSince1970: 1_700_000_300),
            kind: .remote,
            title: "Door opened",
            subtitle: "Front door",
            body: "The front door was opened",
            payloadJSON: """
            {"aps": {"alert": {"title": "Door opened", "body": "x"}, "badge": 1, "sound": null},
             "homeassistant": {"tag": "door", "actions": [{"action": "OK"}, 2, true, false]},
             "ratio": 0.5}
            """
        ),
        .init(
            date: Date(timeIntervalSince1970: 1_700_000_200),
            kind: .local,
            title: nil,
            subtitle: "",
            body: "Body only",
            payloadJSON: "[1, \"two\", null]"
        ),
        .init(
            date: Date(timeIntervalSince1970: 1_700_000_100),
            kind: .liveActivityLocal,
            title: "Washer",
            body: "Washer",
            payloadJSON: "not json"
        ),
        .init(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .liveActivityRemote,
            title: "Remote activity",
            payloadJSON: nil
        ),
    ]

    private func withStore(
        _ entries: [NotificationHistoryEntry],
        _ body: (FakeHistoryStore) async throws -> Void
    ) async rethrows {
        let store = FakeHistoryStore(entries: entries)
        let previous = Current.notificationHistoryStore
        Current.notificationHistoryStore = store
        defer { Current.notificationHistoryStore = previous }
        try await body(store)
    }

    @Test func rendersTheEmptyState() async {
        await withStore([]) { _ in
            let driver = await SwiftUIScreenDriver.show(NotificationHistoryView())
            defer { driver.close() }
            // The kind filter section, then the empty-state row.
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 1 })
        }
    }

    /// Opens every entry's detail screen, which flattens its JSON payload into rows, and copies it.
    @Test func opensEveryEntry() async throws {
        try await withStore(Self.entries) { _ in
            let driver = await SwiftUIScreenDriver.show(NotificationHistoryView())
            defer { driver.close() }
            try await #require(driver.waitUntil { driver.rowCount(inSection: 1) == Self.entries.count })

            for index in Self.entries.indices {
                try await #require(driver.push(IndexPath(item: index, section: 1)), "entry \(index) did not open")
                // The copy button is the only row of the last section.
                await driver.tapRow(IndexPath(item: 0, section: driver.sectionCount - 1))
                await driver.pop()
            }
        }
    }

    /// Pulling the list down reloads the history, picking up entries recorded since.
    @Test func pullToRefreshReloadsTheHistory() async throws {
        try await withStore([]) { store in
            let driver = await SwiftUIScreenDriver.show(NotificationHistoryView())
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 1 })

            store.record(Self.entries[0])
            store.record(Self.entries[1])
            let refreshControl = try #require(driver.list?.refreshControl)
            refreshControl.beginRefreshing()
            refreshControl.sendActions(for: .valueChanged)
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 2 })
        }
    }

    @Test func searchingFiltersTheEntries() async throws {
        try await withStore(Self.entries) { _ in
            let driver = await SwiftUIScreenDriver.show(NotificationHistoryView())
            defer { driver.close() }
            try await #require(driver.waitUntil { driver.rowCount(inSection: 1) == Self.entries.count })

            await driver.search("washer")
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 1 })
            await driver.search("nothing matches this")
            // No match shows the empty-state row instead.
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 1 })
            await driver.search("")
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == Self.entries.count })
        }
    }

    @Test func clearingEmptiesTheHistory() async throws {
        try await withStore(Self.entries) { store in
            let driver = await SwiftUIScreenDriver.show(NotificationHistoryView())
            defer { driver.close() }
            try await #require(driver.waitUntil { driver.rowCount(inSection: 1) == Self.entries.count })
            let top = driver.navigationController?.topViewController
            print("History top: \(String(describing: top)) children: \(top?.children ?? [])")
            print(
                "History bar: \(driver.views(of: UIView.self, in: driver.navigationController?.navigationBar).map { type(of: $0) })"
            )
            print("History bar buttons: \(driver.barButtons)")

            await driver.tapBarButton()
            await #expect(driver.waitUntil { driver.alert != nil })
            await driver.tapAlertButton(L10n.yesLabel)
            #expect(store.entries.isEmpty)
        }
    }

    @Test func viewModelLoadsEntriesNewestFirst() async {
        await withStore(Self.entries.reversed()) { _ in
            let viewModel = NotificationHistoryViewModel()
            viewModel.loadEntries()
            #expect(viewModel.entries.map(\.date) == Self.entries.map(\.date))
        }
    }
}

private final class FakeHistoryStore: NotificationHistoryStoreProtocol {
    private(set) var entries: [NotificationHistoryEntry]

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
