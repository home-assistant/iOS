import AppIntents
import Foundation

/// Home Assistant reports no attendees, so no case is ever produced; the schema requires the shape.
@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeStatus)
enum CalendarAttendeeStatusSchemaEnum: String {
    case accepted
    case declined
    case tentative
    case pending

    static let caseDisplayRepresentations: [CalendarAttendeeStatusSchemaEnum: DisplayRepresentation] = [
        .accepted: .init(title: .init("app_intents.calendar.attendee_status.accepted", defaultValue: "Accepted")),
        .declined: .init(title: .init("app_intents.calendar.attendee_status.declined", defaultValue: "Declined")),
        .tentative: .init(title: .init("app_intents.calendar.attendee_status.tentative", defaultValue: "Tentative")),
        .pending: .init(title: .init("app_intents.calendar.attendee_status.pending", defaultValue: "Pending")),
    ]
}
