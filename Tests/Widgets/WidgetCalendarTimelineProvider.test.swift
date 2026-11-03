@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The calendar widget's timeline: the calendars it merges, the moments its list changes, and when
/// it reloads — plus the picker that offers the stored calendars per server.
///
/// `.isolatedEnvironment`: the database, clock and calendars model are installed per test, and the
/// events are read in child tasks that inherit the test's environment.
@Suite(.isolatedEnvironment)
struct WidgetCalendarTimelineProviderTests {
    @available(iOS 17, *)
    private var provider: WidgetCalendarAppIntentTimelineProvider { .init() }

    // MARK: - Picker

    @available(iOS 17, *)
    @Test func thePickerGroupsTheCalendarsByServer() async throws {
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "a"), serverInfo: .fake())
        Current.servers = servers
        try install(calendars: [
            Self.calendar("work", serverId: "a", order: 0, name: "Work"),
            Self.calendar("chores", serverId: "a", order: 1, name: "Chores"),
            Self.calendar("family", serverId: "orphan", order: 0, name: "Family"),
        ], events: [:])
        let query = WidgetCalendarAppEntityQuery()

        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.count == 2)
        #expect(suggested.sections.flatMap(\.items).map(\.value.id) == ["work", "chores", "family"])

        let byName = try await query.entities(matching: "fam")
        #expect(byName.sections.flatMap(\.items).map(\.value.id) == ["family"])
        let byEntity = try await query.entities(matching: "calendar.chores")
        #expect(byEntity.sections.flatMap(\.items).map(\.value.id) == ["chores"])

        let byId = try await query.entities(for: ["work", "missing"])
        #expect(byId.map(\.name) == ["Work"])
        #expect(!String(describing: byId[0].displayRepresentation.title).isEmpty)
        _ = WidgetCalendarAppIntent.parameterSummary
    }

    // MARK: - Helpers

    /// A fixed mid-morning, so the next midnight is always further away than any test event.
    private static let now: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return today.addingTimeInterval(9 * 3600)
    }()

    private static var nextDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
    }

    private func install(calendars: [HACalendar], events: [String: [HACalendarEvent]]) throws {
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            for calendar in calendars {
                try calendar.insert(db)
            }
        }
        Current.database = { database }
        Current.date = { Self.now }
        let model = StubCalendarsModel(events: events)
        Current.calendarsModel = { model }
    }

    private static func calendar(_ id: String, serverId: String, order: Int, name: String? = nil) -> HACalendar {
        HACalendar(
            id: id,
            serverId: serverId,
            entityId: "calendar.\(id)",
            name: name ?? id.capitalized,
            backgroundColor: "#03A9F4",
            supportedFeatures: 0,
            sortOrder: order
        )
    }

    private static func event(
        _ summary: String,
        startingIn offset: TimeInterval,
        lasting: TimeInterval
    ) -> HACalendarEvent {
        HACalendarEvent(
            summary: summary,
            start: now.addingTimeInterval(offset),
            end: now.addingTimeInterval(offset + lasting),
            isAllDay: false
        )
    }

    @available(iOS 17, *)
    private static func configuration(selecting ids: [String]) -> WidgetCalendarAppIntent {
        let configuration = WidgetCalendarAppIntent()
        configuration.calendars = ids.map { WidgetCalendarAppEntity(
            id: $0,
            entityId: "calendar.\($0)",
            serverId: "a",
            name: $0
        ) }
        configuration.showsCalendarName = true
        return configuration
    }

    private final class StubCalendarsModel: HACalendarsModelProtocol, @unchecked Sendable {
        private let events: [String: [HACalendarEvent]]

        init(events: [String: [HACalendarEvent]]) {
            self.events = events
        }

        func updateModel(_ entities: [HAEntity], server: Server) async {}

        func refresh(server: Server) async -> Bool { true }

        func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
            events[calendar.id] ?? []
        }
    }
}
