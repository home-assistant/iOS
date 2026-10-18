import AppIntents
import Foundation

/// Home Assistant does not report an event status, so this exists only to satisfy the schema shape.
@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventStatus)
enum CalendarEventStatusSchemaEnum: String {
    case confirmed
    case tentative
    case cancelled

    static let caseDisplayRepresentations: [CalendarEventStatusSchemaEnum: DisplayRepresentation] = [
        .confirmed: .init(title: .init("app_intents.calendar.event_status.confirmed", defaultValue: "Confirmed")),
        .tentative: .init(title: .init("app_intents.calendar.event_status.tentative", defaultValue: "Tentative")),
        .cancelled: .init(title: .init("app_intents.calendar.event_status.cancelled", defaultValue: "Cancelled")),
    ]
}
