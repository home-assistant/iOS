import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the event log out against a store holding a known set of events, so SwiftUI evaluates the
/// type filter pills and the event rows (or the empty state).
@MainActor
@Suite(.serialized)
struct ClientEventsLogViewRenderTests {
    private final class FakeEventStore: ClientEventStoreProtocol {
        var events: [ClientEvent]
        private(set) var clearCount = 0

        init(events: [ClientEvent]) {
            self.events = events
        }

        func addEvent(_ event: ClientEvent) {
            events.append(event)
        }

        func getEvents() -> [ClientEvent] {
            events
        }

        func clearAllEvents() {
            clearCount += 1
            events = []
        }
    }

    @Test func viewModelLoadsEventsNewestFirstAndResetsItsFilter() {
        let store = FakeEventStore(events: Self.events)
        withStore(store) {
            let viewModel = ClientEventsLogViewModel()
            viewModel.typeFilter = .notification
            viewModel.loadEvents()

            #expect(viewModel.events.map(\.text) == ["Newest", "Middle", "Oldest"])

            viewModel.resetTypeFilter()
            #expect(viewModel.typeFilter == nil)
        }
    }

    @Test func rendersTheEventsList() {
        let store = FakeEventStore(events: Self.events)
        withStore(store) {
            render(ClientEventsLogView())
            #expect(store.clearCount == 0)
        }
    }

    @Test func rendersTheEmptyState() {
        let store = FakeEventStore(events: [])
        withStore(store) {
            render(ClientEventsLogView())
            #expect(store.events.isEmpty)
        }
    }

    /// `ClientEvent`'s initializer stamps the current date, so each event's date is set afterwards.
    private static let events: [ClientEvent] = [
        event("Middle", type: .serviceCall, payload: ["service": "light.turn_on"], at: 2000),
        event("Newest", type: .notification, payload: ["title": "Hello", "nested": ["key": "value"]], at: 3000),
        event("Oldest", type: .locationUpdate, payload: nil, at: 1000),
    ]

    private static func event(
        _ text: String,
        type: ClientEvent.EventType,
        payload: [String: Any]?,
        at timestamp: TimeInterval
    ) -> ClientEvent {
        var event = ClientEvent(text: text, type: type, payload: payload)
        event.date = Date(timeIntervalSince1970: timestamp)
        return event
    }

    private func withStore(_ store: FakeEventStore, _ body: () -> Void) {
        let previousStore = Current.clientEventStore
        defer { Current.clientEventStore = previousStore }
        Current.clientEventStore = store
        body()
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
