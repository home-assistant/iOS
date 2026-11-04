#if !os(watchOS)
import Foundation

/// One occurrence as the calendar widget draws it.
///
/// Deliberately flat and already resolved: the widget merges events coming from several calendars —
/// potentially on several servers — into one list, so each row carries the colour and the name of
/// the calendar it came from rather than pointing back at it.
public struct WidgetCalendarEventModel: Identifiable, Hashable {
    public let id: String
    public let summary: String
    public let start: Date
    /// Exclusive for all-day events, matching what Home Assistant sends.
    public let end: Date
    public let isAllDay: Bool
    public let calendarName: String
    /// Hex colour (`#rrggbb`) of the calendar the event belongs to.
    public let calendarColor: String

    public init(
        id: String,
        summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarName: String,
        calendarColor: String
    ) {
        self.id = id
        self.summary = summary
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.calendarColor = calendarColor
    }
}
#endif
