import AppIntents
import Foundation
import Shared

/// Adds an event to a Home Assistant calendar on Siri's behalf.
///
/// Attendees are accepted because the schema requires the parameter, but Home Assistant's calendar
/// API has nowhere to put them, so they are ignored rather than silently half-applied.
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventSchemaIntent {
    var title: String
    var startDate: Date
    var endDate: Date?
    var location: EventLocationCases?
    var calendar: CalendarSchemaEntity
    var isAllDay: Bool
    var recurrence: Calendar.RecurrenceRule?
    var attendees: [CalendarAttendeeSchemaEntity]
    var note: AttributedString?

    func perform() async throws -> some ReturnsValue<CalendarEventSchemaEntity> {
        Current.Log.info("Calendar schema intent: adding an event to \(calendar.id)")
        let stored = try CalendarSchemaSupport.calendar(for: calendar, requiring: .createEvent)
        let api = try CalendarSchemaSupport.api(for: stored)
        let end = CalendarSchemaSupport.resolvedEnd(endDate, start: startDate, isAllDay: isAllDay)
        try CalendarSchemaSupport.validate(start: startDate, end: end, isAllDay: isAllDay)

        let knownIds = await Set(CalendarSchemaSupport.cachedEvents(
            on: stored,
            titled: title,
            start: startDate,
            end: end,
            isAllDay: isAllDay
        ).map(\.id))

        try await api.createCalendarEvent(
            entityId: stored.entityId,
            summary: title,
            description: note?.plainText,
            location: location?.plainText,
            rrule: recurrence?.rrule,
            start: startDate,
            end: end,
            isAllDay: isAllDay
        )

        await CalendarSchemaSupport.refreshCachedEvents(for: [stored], touching: [startDate, end])
        if let record = await CalendarSchemaSupport.cachedEvent(
            on: stored,
            titled: title,
            start: startDate,
            end: end,
            isAllDay: isAllDay,
            excluding: knownIds
        ) {
            return .result(value: CalendarEventSchemaEntity(record: record, calendar: calendar))
        }

        return .result(value: CalendarEventSchemaEntity(
            id: "\(stored.serverId)-\(stored.entityId)-\(startDate.timeIntervalSince1970)",
            title: title,
            startDate: startDate,
            endDate: end,
            isAllDay: isAllDay,
            calendar: calendar,
            location: location,
            note: note?.plainText
        ))
    }
}
