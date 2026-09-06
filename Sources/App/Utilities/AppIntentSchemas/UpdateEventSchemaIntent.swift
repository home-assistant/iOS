import AppIntents
import Foundation
import Shared

/// Edits an event on a Home Assistant calendar.
///
/// `calendar/event/update` replaces the whole event, so every field the caller left out is refilled
/// from the event as it stands rather than cleared.
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.updateEvent)
struct UpdateEventSchemaIntent {
    var event: CalendarEventSchemaEntity
    var title: String?
    var attendees: [CalendarAttendeeSchemaEntity]?
    var startDate: Date?
    var endDate: Date?
    var isAllDay: Bool?
    var calendar: CalendarSchemaEntity?
    var recurrence: Calendar.RecurrenceRule?
    var note: String?
    var location: EventLocationCases?
    var span: EventSpanSchemaEnum?

    func perform() async throws -> some ReturnsValue<CalendarEventSchemaEntity> {
        // Moving an event between calendars is a delete plus a create in Home Assistant, which is
        // not what an edit promises, so the event stays where it is.
        let stored = try CalendarSchemaSupport.calendar(for: event.calendar, requiring: .updateEvent)
        let api = try CalendarSchemaSupport.api(for: stored)

        let start = startDate ?? event.startDate
        let allDay = isAllDay ?? event.isAllDay
        let end = CalendarSchemaSupport.resolvedEnd(endDate ?? event.endDate, start: start, isAllDay: allDay)
        try CalendarSchemaSupport.validate(start: start, end: end, isAllDay: allDay)

        let newLocation = location ?? event.location
        let newNote = note ?? event.note

        try await api.updateCalendarEvent(
            entityId: stored.entityId,
            uid: CalendarSchemaSupport.uid(of: event, editing: true),
            recurrenceId: event.recurrenceId,
            recurrenceRange: span?.recurrenceRange,
            summary: title ?? event.title,
            description: newNote,
            location: newLocation?.plainText,
            rrule: recurrence?.rrule,
            start: start,
            end: end,
            isAllDay: allDay
        )

        return .result(value: CalendarEventSchemaEntity(
            id: event.id,
            title: title ?? event.title,
            startDate: start,
            endDate: end,
            isAllDay: allDay,
            calendar: event.calendar,
            location: newLocation,
            note: newNote
        ))
    }
}
