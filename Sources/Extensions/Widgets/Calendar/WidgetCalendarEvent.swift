import Foundation
import Shared

/// One occurrence as the calendar widget draws it.
///
/// Deliberately flat and already resolved: the timeline provider merges events coming from several
/// calendars — potentially on several servers — into one list, so each row has to carry the colour
/// and the name of the calendar it came from rather than pointing back at it.
struct WidgetCalendarEvent: Identifiable, Hashable {
    let id: String
    let summary: String
    let start: Date
    /// Exclusive for all-day events, matching what Home Assistant sends.
    let end: Date
    let isAllDay: Bool
    /// Which server the event came from, so a tap opens that server's calendar panel.
    let serverId: String
    /// The calendar entity the event belongs to, so a tap opens the panel on that calendar.
    let calendarEntityId: String
    let calendarName: String
    /// Hex colour (`#rrggbb`) of the calendar the event belongs to.
    let calendarColor: String

    init(
        id: String,
        summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        serverId: String,
        calendarEntityId: String,
        calendarName: String,
        calendarColor: String
    ) {
        self.id = id
        self.summary = summary
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.serverId = serverId
        self.calendarEntityId = calendarEntityId
        self.calendarName = calendarName
        self.calendarColor = calendarColor
    }

    init(event: HACalendarEvent, calendar: HACalendar) {
        self.init(
            id: HACalendarEventRecord.uniqueId(
                serverId: calendar.serverId,
                calendarEntityId: calendar.entityId,
                uid: event.uid,
                recurrenceId: event.recurrenceId,
                start: event.start
            ),
            summary: event.summary,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            calendarName: calendar.name,
            calendarColor: calendar.backgroundColor
        )
    }

    /// Whether the occurrence has not finished yet at `date`.
    ///
    /// An event that is currently running still belongs on the widget — the iOS Calendar widget
    /// keeps showing it until it ends — so this compares against the end rather than the start.
    func isUpcoming(at date: Date) -> Bool {
        end > date
    }
}

extension WidgetCalendarEvent {
    /// The events still to come at `date`, in the order the widget lists them, capped at `limit`.
    ///
    /// Ordering matches the iOS Calendar widget: chronological, but all-day events lead the day they
    /// belong to instead of being sorted into it at midnight. Ties are broken on the summary so two
    /// events starting at the same minute keep a stable order between timeline entries rather than
    /// swapping places on every refresh.
    static func upcoming(
        _ events: [WidgetCalendarEvent],
        at date: Date,
        limit: Int,
        calendar: Calendar
    ) -> [WidgetCalendarEvent] {
        let sorted = events
            .filter { $0.isUpcoming(at: date) }
            .sorted { lhs, rhs in
                let lhsDay = calendar.startOfDay(for: lhs.start)
                let rhsDay = calendar.startOfDay(for: rhs.start)
                if lhsDay != rhsDay { return lhsDay < rhsDay }
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                if lhs.summary != rhs.summary { return lhs.summary < rhs.summary }
                return lhs.id < rhs.id
            }
        return Array(sorted.prefix(limit))
    }
}
