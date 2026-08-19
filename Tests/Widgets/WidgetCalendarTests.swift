@testable import HomeAssistant

import Foundation
import Shared
import Testing

/// Covers the parts of the calendar widget that decide *what* is shown, separate from the snapshot
/// tests that cover how it looks.
struct WidgetCalendarTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// Monday 18 August 2025, 08:00 UTC.
    private static let now = Date(timeIntervalSince1970: 1_755_504_000)

    private static func event(
        id: String,
        summary: String = "Event",
        startHour: Int,
        endHour: Int,
        isAllDay: Bool = false,
        dayOffset: Int = 0,
        calendarName: String = "Family"
    ) -> WidgetCalendarEvent {
        let day = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ) ?? now
        return WidgetCalendarEvent(
            id: id,
            summary: summary,
            start: calendar.date(byAdding: .hour, value: startHour, to: day) ?? day,
            end: calendar.date(byAdding: .hour, value: endHour, to: day) ?? day,
            isAllDay: isAllDay,
            serverId: "server",
            calendarEntityId: "calendar.family",
            calendarName: calendarName,
            calendarColor: "#4269d0"
        )
    }

    @Test func upcomingDropsEventsThatAlreadyEnded() {
        let finished = Self.event(id: "finished", startHour: 6, endHour: 7)
        let running = Self.event(id: "running", startHour: 7, endHour: 9)
        let later = Self.event(id: "later", startHour: 10, endHour: 11)

        let result = WidgetCalendarEvent.upcoming(
            [finished, running, later],
            at: Self.now,
            limit: 10,
            calendar: Self.calendar
        )

        #expect(result.map(\.id) == ["running", "later"])
    }

    @Test func upcomingPutsAllDayEventsFirstWithinTheirDay() {
        let morning = Self.event(id: "morning", startHour: 9, endHour: 10)
        let allDay = Self.event(id: "all-day", startHour: 0, endHour: 24, isAllDay: true)
        let tomorrow = Self.event(id: "tomorrow", startHour: 9, endHour: 10, dayOffset: 1)
        let tomorrowAllDay = Self.event(
            id: "tomorrow-all-day",
            startHour: 0,
            endHour: 24,
            isAllDay: true,
            dayOffset: 1
        )

        let result = WidgetCalendarEvent.upcoming(
            [tomorrow, morning, tomorrowAllDay, allDay],
            at: Self.now,
            limit: 10,
            calendar: Self.calendar
        )

        #expect(result.map(\.id) == ["all-day", "morning", "tomorrow-all-day", "tomorrow"])
    }

    @Test func upcomingKeepsOnlyTheFirstEventsUpToTheLimit() {
        let events = (0 ..< 6).map { index in
            Self.event(id: "event-\(index)", startHour: 9 + index, endHour: 10 + index)
        }

        let result = WidgetCalendarEvent.upcoming(events, at: Self.now, limit: 2, calendar: Self.calendar)

        #expect(result.map(\.id) == ["event-0", "event-1"])
    }

    /// Two events starting at the same minute must not swap places between timeline entries, so the
    /// order falls back to the summary rather than to whatever the fetch returned.
    @Test func upcomingBreaksTiesDeterministically() {
        let first = Self.event(id: "b", summary: "Alpha", startHour: 9, endHour: 10)
        let second = Self.event(id: "a", summary: "Beta", startHour: 9, endHour: 10)

        let result = WidgetCalendarEvent.upcoming(
            [second, first],
            at: Self.now,
            limit: 10,
            calendar: Self.calendar
        )

        #expect(result.map(\.summary) == ["Alpha", "Beta"])
    }

    @Test func subtitleShowsTheTimeRangeAndOptionallyTheCalendar() {
        let event = Self.event(id: "event", startHour: 9, endHour: 10)

        let withoutName = WidgetCalendarFormatter.subtitle(
            for: event,
            showsCalendarName: false,
            calendar: Self.calendar
        )
        let withName = WidgetCalendarFormatter.subtitle(
            for: event,
            showsCalendarName: true,
            calendar: Self.calendar
        )

        #expect(withoutName.contains("–"))
        #expect(!withoutName.contains("Family"))
        #expect(withName == "\(withoutName) · Family")
    }

    @Test func subtitleLabelsAllDayEvents() {
        let event = Self.event(id: "event", startHour: 0, endHour: 24, isAllDay: true)

        let subtitle = WidgetCalendarFormatter.subtitle(
            for: event,
            showsCalendarName: false,
            calendar: Self.calendar
        )

        #expect(subtitle == L10n.Widgets.Calendar.allDay)
    }

    /// A tap on an event opens its own calendar; a tap that misses one opens the panel on all of
    /// them, so only the first form carries an entity.
    @Test func calendarOpenURLNamesTheCalendarOnlyWhenGivenOne() {
        let withCalendar = AppConstants.calendarOpenURL(serverId: "server", entityId: "calendar.family")
        let withoutCalendar = AppConstants.calendarOpenURL(serverId: "server")

        #expect(withCalendar?.absoluteString.contains("entity_id=calendar.family") == true)
        #expect(withCalendar?.absoluteString.contains("navigate/calendar") == true)
        #expect(withoutCalendar?.absoluteString.contains("entity_id") == false)
        #expect(withoutCalendar?.absoluteString.contains("serverId=server") == true)
        #expect(AppConstants.calendarOpenURL(serverId: "") == nil)
    }

    /// An event running past midnight would otherwise show an end time that reads as the wrong day.
    @Test func subtitleOmitsTheEndOfAnEventThatCrossesMidnight() {
        let event = Self.event(id: "event", startHour: 22, endHour: 26)

        let subtitle = WidgetCalendarFormatter.subtitle(
            for: event,
            showsCalendarName: false,
            calendar: Self.calendar
        )

        #expect(!subtitle.contains("–"))
    }

    @Test func daySectionTitleNamesTodayAndTomorrow() {
        let tomorrow = Self.calendar.date(byAdding: .day, value: 1, to: Self.now) ?? Self.now
        let nextWeek = Self.calendar.date(byAdding: .day, value: 7, to: Self.now) ?? Self.now

        #expect(WidgetCalendarFormatter.daySectionTitle(
            for: Self.now,
            relativeTo: Self.now,
            calendar: Self.calendar
        ) == L10n.Widgets.Calendar.today)
        #expect(WidgetCalendarFormatter.daySectionTitle(
            for: tomorrow,
            relativeTo: Self.now,
            calendar: Self.calendar
        ) == L10n.Widgets.Calendar.tomorrow)

        let later = WidgetCalendarFormatter.daySectionTitle(
            for: nextWeek,
            relativeTo: Self.now,
            calendar: Self.calendar
        )
        #expect(later != L10n.Widgets.Calendar.today)
        #expect(later != L10n.Widgets.Calendar.tomorrow)
    }

    /// The colour and the calendar name have to survive the merge, because a row has no way back to
    /// the calendar it came from once the lists are flattened.
    @Test func eventCarriesItsCalendarIdentity() {
        let haCalendar = HACalendar(
            id: "server-calendar.family",
            serverId: "server",
            entityId: "calendar.family",
            name: "Family",
            backgroundColor: "#f4bd4a",
            supportedFeatures: 0,
            sortOrder: 1
        )
        let source = HACalendarEvent(
            summary: "Dentist",
            start: Self.now,
            end: Self.now.addingTimeInterval(3600),
            isAllDay: false,
            uid: "uid-1"
        )

        let event = WidgetCalendarEvent(event: source, calendar: haCalendar)

        #expect(event.summary == "Dentist")
        #expect(event.calendarEntityId == "calendar.family")
        #expect(event.calendarName == "Family")
        #expect(event.calendarColor == "#f4bd4a")
        #expect(event.serverId == "server")
        #expect(event.isUpcoming(at: Self.now))
        #expect(!event.isUpcoming(at: Self.now.addingTimeInterval(7200)))
    }
}
