import AppIntents
import Foundation

/// Which occurrences of a recurring event an edit or deletion applies to. Maps onto Home
/// Assistant's `recurrence_range`, which is empty for one occurrence and `THISANDFUTURE` otherwise.
@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventSpan)
enum EventSpanSchemaEnum: String {
    case this
    case future
    case all

    static let caseDisplayRepresentations: [EventSpanSchemaEnum: DisplayRepresentation] = [
        .this: .init(title: .init("app_intents.calendar.span.this", defaultValue: "This event only")),
        .future: .init(title: .init("app_intents.calendar.span.future", defaultValue: "Future events")),
        .all: .init(title: .init("app_intents.calendar.span.all", defaultValue: "All events")),
    ]

    /// Home Assistant only distinguishes "this one" from "this and everything after"; deleting or
    /// editing every occurrence is addressed by the event's uid with no range at all.
    var recurrenceRange: String? {
        switch self {
        case .this: nil
        case .future, .all: "THISANDFUTURE"
        }
    }
}
