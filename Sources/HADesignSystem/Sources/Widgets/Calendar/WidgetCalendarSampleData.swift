#if !os(watchOS)
import Foundation

/// Fixed sample events for previews and the component gallery.
///
/// Pinned to a fixed "now" so a preview drawn today looks the same as one drawn next week, and
/// spread over three days so the day-grouped families have something to group.
public enum WidgetCalendarSampleData {
    /// Monday 18 August 2025, 08:00 UTC.
    public static let referenceDate = Date(timeIntervalSince1970: 1_755_504_000)

    /// The frontend calendar palette's first three colours.
    private static let colors = ["#4269d0", "#f4bd4a", "#ff725c"]

    public static let events: [WidgetCalendarEventModel] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        return [
            event(index: 0, colorIndex: 0, day: today, startHour: nil, endHour: nil, calendar: calendar),
            event(index: 1, colorIndex: 1, day: today, startHour: 9, endHour: 10, calendar: calendar),
            event(index: 2, colorIndex: 0, day: today, startHour: 13, endHour: 14, calendar: calendar),
            event(index: 3, colorIndex: 2, day: today, startHour: 18, endHour: 20, calendar: calendar),
            event(index: 4, colorIndex: 1, day: tomorrow, startHour: nil, endHour: nil, calendar: calendar),
            event(index: 5, colorIndex: 2, day: tomorrow, startHour: 11, endHour: 12, calendar: calendar),
            event(index: 6, colorIndex: 0, day: dayAfter, startHour: 8, endHour: 9, calendar: calendar),
            event(index: 7, colorIndex: 1, day: dayAfter, startHour: 16, endHour: 17, calendar: calendar),
        ]
    }()

    private static func event(
        index: Int,
        colorIndex: Int,
        day: Date,
        startHour: Int?,
        endHour: Int?,
        calendar: Calendar
    ) -> WidgetCalendarEventModel {
        let start = startHour.flatMap { calendar.date(byAdding: .hour, value: $0, to: day) } ?? day
        let end = endHour.flatMap { calendar.date(byAdding: .hour, value: $0, to: day) }
            ?? calendar.date(byAdding: .day, value: 1, to: day)
            ?? day

        return WidgetCalendarEventModel(
            id: "widget-calendar-sample-\(index)",
            summary: "Event \(index + 1)",
            start: start,
            end: end,
            isAllDay: startHour == nil,
            calendarName: "Calendar \(colorIndex + 1)",
            calendarColor: colors[colorIndex % colors.count]
        )
    }
}
#endif
