#if !os(watchOS)
import Foundation

/// The date and time strings the calendar widget draws.
///
/// Everything here takes an explicit `Calendar` rather than reading `Calendar.current`, and derives
/// the locale and time zone from it. Passing a fixed calendar alongside a fixed reference date is
/// then enough to pin every string the view produces, instead of the snapshots drifting with the
/// region settings of whatever machine renders them.
public enum WidgetCalendarText {
    /// "9:41 AM" — the time alone, since the day is already established by the row's section.
    public static func time(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(.init(date: .omitted, time: .shortened), calendar: calendar))
    }

    /// "TUE" — the abbreviated weekday the date badge shows above the day number.
    ///
    /// Uppercased with the calendar's own locale rather than `localizedUppercase`, which would
    /// apply the device's casing rules to a string formatted in a different language.
    public static func weekdayAbbreviation(_ date: Date, calendar: Calendar) -> String {
        date
            .formatted(style(.dateTime.weekday(.abbreviated), calendar: calendar))
            .uppercased(with: calendar.locale ?? .autoupdatingCurrent)
    }

    /// "18" — the day of the month, on its own.
    public static func dayNumber(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(.dateTime.day(), calendar: calendar))
    }

    /// The heading above a day's events in the larger families: "Today", "Tomorrow", or a weekday
    /// and date for anything further out.
    public static func daySectionTitle(
        for day: Date,
        relativeTo reference: Date,
        calendar: Calendar,
        strings: WidgetCalendarStrings
    ) -> String {
        let startOfDay = calendar.startOfDay(for: day)
        let startOfReference = calendar.startOfDay(for: reference)
        if startOfDay == startOfReference {
            return strings.today
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfReference), startOfDay == tomorrow {
            return strings.tomorrow
        }
        return day.formatted(style(.dateTime.weekday(.abbreviated).month(.abbreviated).day(), calendar: calendar))
    }

    /// The secondary line under an event: which day it falls on when that isn't the day being shown,
    /// when it happens, and — when the widget merges several calendars — which calendar it came from.
    ///
    /// `showsDay` is what the families without a day heading turn on. Without it a row for tomorrow
    /// is indistinguishable from one for today, since the only date on those layouts is the badge.
    public static func subtitle(
        for event: WidgetCalendarEventModel,
        relativeTo reference: Date,
        showsDay: Bool,
        showsCalendarName: Bool,
        calendar: Calendar,
        strings: WidgetCalendarStrings
    ) -> String {
        let day = showsDay
            ? dayLabel(for: event, relativeTo: reference, calendar: calendar, strings: strings)
            : nil
        // A row that already names another day has said the important part, so it drops the end time
        // rather than pushing the calendar name out of a narrow layout.
        var parts = [
            day,
            timing(for: event, calendar: calendar, startOnly: day != nil, strings: strings),
        ].compactMap { $0 }
        if showsCalendarName {
            parts.append(event.calendarName)
        }
        return parts.joined(separator: " · ")
    }

    /// The day an event reads as, or `nil` when that is the day already on screen.
    ///
    /// An event that started earlier and is still running counts as today, matching how the larger
    /// families group it under the current day rather than the one it began on.
    private static func dayLabel(
        for event: WidgetCalendarEventModel,
        relativeTo reference: Date,
        calendar: Calendar,
        strings: WidgetCalendarStrings
    ) -> String? {
        let day = calendar.startOfDay(for: max(event.start, reference))
        guard day != calendar.startOfDay(for: reference) else { return nil }
        return daySectionTitle(for: day, relativeTo: reference, calendar: calendar, strings: strings)
    }

    /// All-day events say so; a timed event shows its range, collapsed to just the start when it
    /// runs past midnight and an end time on its own would read as the wrong day.
    private static func timing(
        for event: WidgetCalendarEventModel,
        calendar: Calendar,
        startOnly: Bool,
        strings: WidgetCalendarStrings
    ) -> String {
        guard !event.isAllDay else { return strings.allDay }
        let start = time(event.start, calendar: calendar)
        guard !startOnly, calendar.isDate(event.start, inSameDayAs: event.end), event.end > event.start else {
            return start
        }
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
#endif
