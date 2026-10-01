import AppIntents
import Foundation

/// Home Assistant's calendar API has no attendee concept, so this only ever appears as an empty
/// list on an event. It exists because the schema requires the property to have this shape.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.attendee)
struct CalendarAttendeeSchemaEntity: TransientAppEntity {
    var person: IntentPerson
    var status: CalendarAttendeeStatusSchemaEnum?
    var type: CalendarAttendeeTypeSchemaEnum?
    var isAttendanceOptional: Bool

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init("app_intents.calendar.attendee.name", defaultValue: "Attendee"))
    }

    init() {
        self.person = IntentPerson(handle: .init(applicationDefined: ""))
        self.isAttendanceOptional = false
    }
}
