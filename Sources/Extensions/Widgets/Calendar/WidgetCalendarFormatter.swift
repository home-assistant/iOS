import Foundation
import Shared

/// The date and time strings the calendar widget draws.
///
/// The formatting itself lives in the design system's `WidgetCalendarText`; this is where the app's
/// translations are handed to it, so the widget and the component gallery format identically while
/// only the app owns the strings.
enum WidgetCalendarFormatter {
    /// The app's own copy for the calendar widget.
    static var strings: WidgetCalendarStrings {
        .init(
            title: L10n.Widgets.Calendar.title,
            selectCalendars: L10n.Widgets.Calendar.selectCalendars,
            noEvents: L10n.Widgets.Calendar.noEvents,
            today: L10n.Widgets.Calendar.today,
            tomorrow: L10n.Widgets.Calendar.tomorrow,
            allDay: L10n.Widgets.Calendar.allDay
        )
    }

    /// "9:41 AM" — the time alone, since the day is already established by the row's section.
    static func time(_ date: Date, calendar: Calendar) -> String {
        WidgetCalendarText.time(date, calendar: calendar)
    }

    /// "TUE" — the abbreviated weekday the date badge shows above the day number.
    static func weekdayAbbreviation(_ date: Date, calendar: Calendar) -> String {
        WidgetCalendarText.weekdayAbbreviation(date, calendar: calendar)
    }

    /// "18" — the day of the month, on its own.
    static func dayNumber(_ date: Date, calendar: Calendar) -> String {
        WidgetCalendarText.dayNumber(date, calendar: calendar)
    }

    /// The heading above a day's events in the larger families: "Today", "Tomorrow", or a weekday
    /// and date for anything further out.
    static func daySectionTitle(for day: Date, relativeTo reference: Date, calendar: Calendar) -> String {
        WidgetCalendarText.daySectionTitle(
            for: day,
            relativeTo: reference,
            calendar: calendar,
            strings: strings
        )
    }

    /// The secondary line under an event: which day it falls on when that isn't the day being shown,
    /// when it happens, and — when the widget merges several calendars — which calendar it came from.
    static func subtitle(
        for event: WidgetCalendarEvent,
        relativeTo reference: Date,
        showsDay: Bool,
        showsCalendarName: Bool,
        calendar: Calendar
    ) -> String {
        WidgetCalendarText.subtitle(
            for: event.designSystemModel,
            relativeTo: reference,
            showsDay: showsDay,
            showsCalendarName: showsCalendarName,
            calendar: calendar,
            strings: strings
        )
    }
}
