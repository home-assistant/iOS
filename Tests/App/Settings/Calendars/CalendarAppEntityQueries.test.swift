import AppIntents
import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Shared state: both queries read the calendars from `Current.database` and the events from
/// `Current.calendarsModel`.
@Suite(.sharedState)
@MainActor
struct CalendarAppEntityQueriesTests {
    @Test func calendarQueryFindsGroupsAndSuggests() async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let query = HACalendarAppEntityQuery()
            let found = try await query.entities(for: [world.writable.id, "missing"])
            #expect(found.map(\.id) == [world.writable.id])

            let matching = try await query.entities(matching: "holi")
            #expect(matching.sections.flatMap(\.items).map(\.value.id) == [world.readOnly.id])
            let byEntity = try await query.entities(matching: "calendar.family")
            #expect(byEntity.sections.flatMap(\.items).count == 1)

            let suggested = try await query.suggestedEntities()
            #expect(suggested.sections.count == 1)
            #expect(suggested.sections.flatMap(\.items).count == 2)
        }
    }

    @Test func eventQuerySuggestsUpcomingEventsFromEveryCalendar() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        world.model.events = [
            HACalendarEvent(summary: "Later", start: Date().addingTimeInterval(7200), end: Date(), isAllDay: false),
            HACalendarEvent(summary: "Sooner", start: Date().addingTimeInterval(60), end: Date(), isAllDay: false),
        ]
        try await world.run {
            let query = HACalendarEventAppEntityQuery()
            let suggested = try await query.suggestedEntities()
            // Two calendars, two events each, soonest first.
            #expect(suggested.count == 4)
            #expect(suggested.first?.payload.summary == "Sooner")
            #expect(Set(world.model.asked) == ["calendar.family", "calendar.holidays"])

            let matching = try await query.entities(matching: "later")
            #expect(matching.count == 2)

            let byId = try await query.entities(for: [suggested[0].id, "not-base64"])
            #expect(byId.count == 1)
        }
    }

    @Test func eventQueryHasNothingWithoutCalendars() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        let previous = Current.database
        Current.database = { world.database }
        defer { Current.database = previous }
        let suggested = try await HACalendarEventAppEntityQuery().suggestedEntities()
        #expect(suggested.isEmpty)
    }
}
