import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// A Home Assistant calendar event in the shape Apple Intelligence understands.
///
/// Home Assistant has no concept of attendees, organizers, alarms or travel time, so those are
/// empty or nil — which is the truthful answer for an event that has none, not a placeholder.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.event)
struct CalendarEventSchemaEntity: IndexedEntity {
    static let defaultQuery = CalendarEventSchemaEntityQuery()

    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendar: CalendarSchemaEntity
    var location: EventLocationCases?
    var virtualLocation: URL?
    var attendees: [CalendarAttendeeSchemaEntity]
    var organizers: [IntentPerson]
    var recurrence: Calendar.RecurrenceRule?
    var alarms: [EventAlarmCases]
    var status: CalendarEventStatusSchemaEnum?
    var travelTime: Duration?
    var note: String?

    /// How `calendar/event/update` and `/delete` address the event. Home Assistant omits `uid` for
    /// integrations that don't supply one, and such an event can be listed but not modified.
    var uid: String?
    var recurrenceId: String?

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(title)", image: .init(systemName: "calendar"))
    }

    init(record: HACalendarEventRecord, calendar: CalendarSchemaEntity) {
        self.id = record.id
        self.uid = record.uid
        self.recurrenceId = record.recurrenceId
        self.title = record.summary
        self.startDate = record.start
        self.endDate = record.end
        self.isAllDay = record.isAllDay
        self.calendar = calendar
        self.location = record.location?.nilIfEmpty.map(EventLocationCases.text)
        self.note = record.eventDescription?.nilIfEmpty
        // Home Assistant exposes none of these.
        self.virtualLocation = nil
        self.attendees = []
        self.organizers = []
        self.recurrence = nil
        self.alarms = []
        self.status = nil
        self.travelTime = nil
    }

    /// An event described by what was just asked for. `calendar/event/create` and `/update` return
    /// nothing, so this is the only shape available until the calendar is read again.
    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendar: CalendarSchemaEntity,
        location: EventLocationCases?,
        note: String?
    ) {
        self.id = id
        self.uid = nil
        self.recurrenceId = nil
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.location = location
        self.note = note
        self.virtualLocation = nil
        self.attendees = []
        self.organizers = []
        self.recurrence = nil
        self.alarms = []
        self.status = nil
        self.travelTime = nil
    }
}
