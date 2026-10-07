import AppIntents
import Foundation

/// The repeat presets the frontend's recurrence editor offers
/// (`RepeatFrequency` in `src/panels/calendar/recurrence.ts`).
///
/// The editor's extra controls — interval, weekday set, end date/count — only appear once a
/// frequency is chosen and are left out here; the rule this produces is what the frontend sends for
/// a freshly picked preset.
@available(iOS 17.0, *)
enum CalendarEventRepeatAppEnum: String, Codable, Sendable, AppEnum {
    case none
    case yearly
    case monthly
    case weekly
    case daily

    /// The iCalendar RRULE for the preset, or `nil` for a one-off event.
    ///
    /// Weekly and monthly are anchored to the event's start, matching how the editor seeds its
    /// weekday and day-of-month controls from `dtstart`.
    func rrule(startingOn start: Date) -> String? {
        let calendar = Calendar.current
        switch self {
        case .none:
            return nil
        case .yearly:
            return "FREQ=YEARLY"
        case .monthly:
            return "FREQ=MONTHLY;BYMONTHDAY=\(calendar.component(.day, from: start))"
        case .weekly:
            let weekday = calendar.component(.weekday, from: start)
            return "FREQ=WEEKLY;BYDAY=\(Self.weekdayCodes[(weekday - 1) % Self.weekdayCodes.count])"
        case .daily:
            return "FREQ=DAILY"
        }
    }

    /// RFC 5545 weekday codes, indexed the way `Calendar`'s `.weekday` counts (1 = Sunday).
    private static let weekdayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("app_intents.calendar.create_event.repeat.title", defaultValue: "Repeat")
    )
    static var caseDisplayRepresentations: [CalendarEventRepeatAppEnum: DisplayRepresentation] = [
        .none: DisplayRepresentation(title: .init(
            "app_intents.calendar.repeat.none",
            defaultValue: "No repeat"
        )),
        .yearly: DisplayRepresentation(title: .init(
            "app_intents.calendar.repeat.yearly",
            defaultValue: "Yearly"
        )),
        .monthly: DisplayRepresentation(title: .init(
            "app_intents.calendar.repeat.monthly",
            defaultValue: "Monthly"
        )),
        .weekly: DisplayRepresentation(title: .init(
            "app_intents.calendar.repeat.weekly",
            defaultValue: "Weekly"
        )),
        .daily: DisplayRepresentation(title: .init(
            "app_intents.calendar.repeat.daily",
            defaultValue: "Daily"
        )),
    ]
}
