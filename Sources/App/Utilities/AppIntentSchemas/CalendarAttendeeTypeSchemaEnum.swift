import AppIntents
import Foundation

/// Home Assistant reports no attendees, so no case is ever produced; the schema requires the shape.
@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeType)
enum CalendarAttendeeTypeSchemaEnum: String {
    case person
    case room
    case resource

    static let caseDisplayRepresentations: [CalendarAttendeeTypeSchemaEnum: DisplayRepresentation] = [
        .person: .init(title: .init("app_intents.calendar.attendee_type.person", defaultValue: "Person")),
        .room: .init(title: .init("app_intents.calendar.attendee_type.room", defaultValue: "Room")),
        .resource: .init(title: .init("app_intents.calendar.attendee_type.resource", defaultValue: "Resource")),
    ]
}
