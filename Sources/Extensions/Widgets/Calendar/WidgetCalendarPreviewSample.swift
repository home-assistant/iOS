import Foundation
import Shared

/// Fixed sample events used to draw the calendar widget in the iOS widget gallery and in previews.
///
/// WidgetKit asks every widget in the extension for a snapshot while the user browses the picker,
/// before anything has been configured. Building that from live data means database reads and
/// server round trips inside the extension's tight budget, to draw something that isn't the user's
/// data anyway — so the provider serves this instead, the same way the energy and to-do widgets do.
///
/// Following `WidgetPreviewSample`, the labels are built from strings the app already translates
/// plus a numeral, so the gallery stays localized without preview-only keys.
enum WidgetCalendarPreviewSample {
    /// Intentionally matches no real server — nothing in a gallery preview resolves, and a fake id
    /// keeps the sample rows from deep-linking somewhere real.
    static let previewServerId = "widget-calendar-preview"

    /// A fixed "now" — Monday 18 August 2025, 08:00 UTC — so previews and snapshots draw the same
    /// layout no matter when they run.
    static let referenceDate = Date(timeIntervalSince1970: 1_755_504_000)

    /// Events laid out around `referenceDate`: a couple today, then the following two days, so
    /// every family has something to show and the larger ones show day grouping.
    static func events(referenceDate: Date, calendar: Calendar) -> [WidgetCalendarEvent] {
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        return [
            event(index: 0, calendarIndex: 0, day: today, startHour: nil, endHour: nil, calendar: calendar),
            event(index: 1, calendarIndex: 1, day: today, startHour: 9, endHour: 10, calendar: calendar),
            event(index: 2, calendarIndex: 0, day: today, startHour: 13, endHour: 14, calendar: calendar),
            event(index: 3, calendarIndex: 2, day: today, startHour: 18, endHour: 20, calendar: calendar),
            event(index: 4, calendarIndex: 1, day: tomorrow, startHour: nil, endHour: nil, calendar: calendar),
            event(index: 5, calendarIndex: 2, day: tomorrow, startHour: 11, endHour: 12, calendar: calendar),
            event(index: 6, calendarIndex: 0, day: dayAfter, startHour: 8, endHour: 9, calendar: calendar),
            event(index: 7, calendarIndex: 1, day: dayAfter, startHour: 16, endHour: 17, calendar: calendar),
        ]
    }

    /// "Calendar 1", "Calendar 2"… — a translated noun plus a numeral, matching how the sample
    /// scripts are named in `WidgetPreviewSample`.
    static func calendarName(index: Int) -> String {
        "\(CoreStrings.componentCalendarTitle) \(index + 1)"
    }

    /// A whole hour offset is enough for a preview, so all-day events are simply the ones with no
    /// hours at all.
    private static func event(
        index: Int,
        calendarIndex: Int,
        day: Date,
        startHour: Int?,
        endHour: Int?,
        calendar: Calendar
    ) -> WidgetCalendarEvent {
        let start = startHour.flatMap { calendar.date(byAdding: .hour, value: $0, to: day) } ?? day
        let end = endHour.flatMap { calendar.date(byAdding: .hour, value: $0, to: day) }
            ?? calendar.date(byAdding: .day, value: 1, to: day)
            ?? day

        return WidgetCalendarEvent(
            id: "widget-calendar-preview-\(index)",
            summary: "\(L10n.AppIntents.Calendar.Event.Entity.name) \(index + 1)",
            start: start,
            end: end,
            isAllDay: startHour == nil,
            serverId: previewServerId,
            calendarEntityId: "calendar.preview_\(calendarIndex + 1)",
            calendarName: calendarName(index: calendarIndex),
            calendarColor: HACalendar.defaultColor(at: calendarIndex)
        )
    }
}
