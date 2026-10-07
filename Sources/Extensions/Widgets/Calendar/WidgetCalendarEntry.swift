import Foundation
import WidgetKit

/// One rendering of the calendar widget.
///
/// The provider emits several of these per timeline — one per moment the list visibly changes, such
/// as an event ending or the day rolling over — so `date` is both WidgetKit's "show this from" and
/// the "now" the view lays itself out against. Nothing in the view reads the clock, which is what
/// makes it snapshot-testable.
struct WidgetCalendarEntry: TimelineEntry {
    let date: Date
    let events: [WidgetCalendarEvent]
    /// How many calendars the entry was built from. Zero means nothing is selected and no calendar
    /// is stored either, which the view turns into a "configure me" state rather than "no events".
    let calendarCount: Int
    /// Whether each row names the calendar it came from, mirroring the widget's configuration.
    let showsCalendarName: Bool
    /// The server a tap anywhere other than an event opens the calendar panel on — the first
    /// selected calendar's. `nil` when nothing is selected and there is no panel to open.
    let serverId: String?

    init(
        date: Date,
        events: [WidgetCalendarEvent],
        calendarCount: Int,
        showsCalendarName: Bool,
        serverId: String?
    ) {
        self.date = date
        self.events = events
        self.calendarCount = calendarCount
        self.showsCalendarName = showsCalendarName
        self.serverId = serverId
    }
}
