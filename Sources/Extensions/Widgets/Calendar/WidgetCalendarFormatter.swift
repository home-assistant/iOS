import Foundation
import Shared

/// The date and time strings the calendar widget draws.
///
/// Everything here takes an explicit `Calendar` rather than reading `Calendar.current`, and derives
/// the locale and time zone from it. Passing a fixed calendar alongside a fixed reference date is
/// then enough to pin every string the view produces, instead of the snapshots drifting with the
/// region settings of whatever machine renders them.
enum WidgetCalendarFormatter {
    /// "9:41 AM" — the time alone, since the day is already established by the row's section.
    static func time(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(.init(date: .omitted, time: .shortened), calendar: calendar))
    }

    /// "TUE" — the abbreviated weekday the date badge shows above the day number.
    static func weekdayAbbreviation(_ date: Date, calendar: Calendar) -> String {
        date
            .formatted(style(.dateTime.weekday(.abbreviated), calendar: calendar))
            .localizedUppercase
    }

    /// "18" — the day of the month, on its own.
    static func dayNumber(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(.dateTime.day(), calendar: calendar))
    }

    /// The heading above a day's events in the larger families: "Today", "Tomorrow", or a weekday
    /// and date for anything further out.
    static func daySectionTitle(for day: Date, relativeTo reference: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: day)
        let startOfReference = calendar.startOfDay(for: reference)
        if startOfDay == startOfReference {
            return L10n.Widgets.Calendar.today
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfReference), startOfDay == tomorrow {
            return L10n.Widgets.Calendar.tomorrow
        }
        return day.formatted(style(.dateTime.weekday(.abbreviated).month(.abbreviated).day(), calendar: calendar))
    }

    /// The secondary line under an event: when it happens, and — when the widget merges several
    /// calendars — which calendar it came from.
    static func subtitle(for event: WidgetCalendarEvent, showsCalendarName: Bool, calendar: Calendar) -> String {
        var parts = [timing(for: event, calendar: calendar)]
        if showsCalendarName {
            parts.append(event.calendarName)
        }
        return parts.joined(separator: " · ")
    }

    /// All-day events say so; a timed event shows its range, collapsed to just the start when it
    /// runs past midnight and an end time on its own would read as the wrong day.
    private static func timing(for event: WidgetCalendarEvent, calendar: Calendar) -> String {
        guard !event.isAllDay else { return L10n.Widgets.Calendar.allDay }
        let start = time(event.start, calendar: calendar)
        guard calendar.isDate(event.start, inSameDayAs: event.end), event.end > event.start else { return start }
        return "\(start) – \(time(event.end, calendar: calendar))"
    }

    private static func style(_ style: Date.FormatStyle, calendar: Calendar) -> Date.FormatStyle {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = calendar.locale ?? .autoupdatingCurrent
        return style
    }
}
