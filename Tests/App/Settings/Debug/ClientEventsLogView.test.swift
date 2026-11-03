@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the client event log out over a fake event store, opens an event, searches it and clears it.
///
/// `.sharedState`: the test swaps `Current.clientEventStore`, which the screen reads from `onAppear`
/// and from its clear confirmation.
@Suite(.sharedState)
@MainActor
struct ClientEventsLogViewTests {
    private final class FakeClientEventStore: ClientEventStoreProtocol {
        var events: [ClientEvent]
        private(set) var clearCount = 0

        init(events: [ClientEvent]) {
            self.events = events
        }

        func addEvent(_ event: ClientEvent) { events.append(event) }
        func getEvents() -> [ClientEvent] { events }
        func clearAllEvents() {
            clearCount += 1
            events = []
        }
    }

    private func withStore(_ store: FakeClientEventStore, _ body: () async throws -> Void) async rethrows {
        let previous = Current.clientEventStore
        Current.clientEventStore = store
        defer { Current.clientEventStore = previous }
        try await body()
    }

    /// `ClientEvent.init` ignores its `date` argument (the stored default, `Current.date()`, wins), so
    /// the dates are set afterwards: left to the default they depend on whatever `Current.date` is.
    private static let events = [
        event("Network request failed", .networkRequest, payload: ["url": "https://example.com", "status": 500], at: 0),
        event("Notification received", .notification, at: 100),
        event("Location updated", .locationUpdate, at: 200),
    ]

    private static func event(
        _ text: String,
        _ type: ClientEvent.EventType,
        payload: [String: Any] = [:],
        at offset: TimeInterval
    ) -> ClientEvent {
        var event = ClientEvent(text: text, type: type, payload: payload)
        event.date = Date(timeIntervalSince1970: 1_700_000_000 + offset)
        return event
    }

    @Test func viewModelLoadsNewestFirstAndResetsTheFilter() async {
        await withStore(FakeClientEventStore(events: Self.events)) {
            let viewModel = ClientEventsLogViewModel()
            viewModel.loadEvents()
            #expect(viewModel.events.map(\.text) == [
                "Location updated",
                "Notification received",
                "Network request failed",
            ])
            viewModel.typeFilter = .notification
            viewModel.resetTypeFilter()
            #expect(viewModel.typeFilter == nil)
        }
    }

    @Test func listsOpensAndSearchesEvents() async {
        await withStore(FakeClientEventStore(events: Self.events)) {
            let harness = await SettingsScreenHarness.show(ClientEventsLogView())
            // The type filter pills, then one row per event.
            let reached1 = await harness.waitUntil { harness.rows.filter { $0.section > 0 }.count == 3 }
            #expect(reached1)

            if let first = harness.rows.first(where: { $0.section > 0 }), await harness.push(first) {
                await harness.pop()
            }

            await harness.search("notification")
            #expect(harness.rows.filter { $0.section > 0 }.count == 1)
            await harness.search("nothing like this")
            // The empty state takes the place of the events.
            #expect(harness.rows.filter { $0.section > 0 }.count == 1)
            await harness.search("")
            await harness.close()
        }
    }

    @Test func clearingAfterConfirmationEmptiesTheStore() async {
        let store = FakeClientEventStore(events: Self.events)
        await withStore(store) {
            let harness = await SettingsScreenHarness.show(ClientEventsLogView())
            await harness.tapBarButton()
            let reached2 = await harness.waitUntil(timeout: 5) { harness.alert != nil }
            #expect(reached2)
            await harness.tapAlertButton(L10n.yesLabel)
            #expect(store.clearCount == 1)
            await harness.close()
        }
    }

    @Test func showsTheEmptyStateWithoutEvents() async {
        await withStore(FakeClientEventStore(events: [])) {
            let harness = await SettingsScreenHarness.show(ClientEventsLogView())
            #expect(harness.rows.filter { $0.section > 0 }.count == 1)
            await harness.close()
        }
    }

    /// Pulling the list down reads the store again, so events logged since it opened show up.
    @Test func pullingToRefreshShowsNewEvents() async throws {
        let store = FakeClientEventStore(events: Array(Self.events.prefix(1)))
        try await withStore(store) {
            let driver = await SwiftUIScreenDriver.show(ClientEventsLogView())
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rows.filter { $0.section > 0 }.count == 1 })

            store.events = Self.events
            let refreshed = await driver.pullToRefresh()
            try #require(refreshed)
            await #expect(driver.waitUntil { driver.rows.filter { $0.section > 0 }.count == 3 })
        }
    }
}
