import AppIntents
import Foundation

/// How far a delete reaches into a recurring series, matching the frontend's `RecurrenceRange`
/// (`src/data/calendar.ts`). Ignored for events that do not recur.
@available(iOS 17.0, *)
enum CalendarEventDeleteScopeAppEnum: String, Codable, Sendable, AppEnum {
    /// `RecurrenceRange.THISEVENT` — the empty string on the wire.
    case thisEvent
    /// `RecurrenceRange.THISANDFUTURE`.
    case thisAndFuture

    /// The value Home Assistant expects in `recurrence_range`.
    var recurrenceRange: String {
        switch self {
        case .thisEvent: ""
        case .thisAndFuture: "THISANDFUTURE"
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("app_intents.calendar.delete_event.scope.title", defaultValue: "Delete")
    )
    static var caseDisplayRepresentations: [CalendarEventDeleteScopeAppEnum: DisplayRepresentation] = [
        .thisEvent: DisplayRepresentation(title: .init(
            "app_intents.calendar.delete_event.scope.this_event",
            defaultValue: "This event only"
        )),
        .thisAndFuture: DisplayRepresentation(title: .init(
            "app_intents.calendar.delete_event.scope.this_and_future",
            defaultValue: "This and all future events"
        )),
    ]
}
