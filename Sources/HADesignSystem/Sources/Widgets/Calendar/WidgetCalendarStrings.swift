#if !os(watchOS)
import Foundation

/// The copy the calendar widget draws.
///
/// Handed in rather than looked up: the design system ships no string tables, and the app's
/// translations are the ones that have to end up on screen.
public struct WidgetCalendarStrings {
    public let title: String
    public let selectCalendars: String
    public let noEvents: String
    public let today: String
    public let tomorrow: String
    public let allDay: String

    public init(
        title: String,
        selectCalendars: String,
        noEvents: String,
        today: String,
        tomorrow: String,
        allDay: String
    ) {
        self.title = title
        self.selectCalendars = selectCalendars
        self.noEvents = noEvents
        self.today = today
        self.tomorrow = tomorrow
        self.allDay = allDay
    }

    /// English stand-ins, for previews and the component gallery.
    public static let preview = WidgetCalendarStrings(
        title: "Calendar",
        selectCalendars: "Select the calendars to show",
        noEvents: "No events",
        today: "Today",
        tomorrow: "Tomorrow",
        allDay: "All day"
    )
}
#endif
