import AppIntents
import Foundation
import Shared

/// Removes an event from a Home Assistant calendar.
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.deleteEvent)
struct DeleteEventSchemaIntent {
    var entity: CalendarEventSchemaEntity
    var span: EventSpanSchemaEnum?

    func perform() async throws -> some IntentResult {
        Current.Log.info("Calendar schema intent: deleting event \(entity.id)")
        let stored = try CalendarSchemaSupport.calendar(for: entity.calendar, requiring: .deleteEvent)
        let api = try CalendarSchemaSupport.api(for: stored)

        try await api.deleteCalendarEvent(
            entityId: stored.entityId,
            uid: CalendarSchemaSupport.uid(of: entity, editing: false),
            recurrenceId: entity.recurrenceId,
            recurrenceRange: span?.recurrenceRange
        )
        await CalendarSchemaSupport.refreshCachedEvents(for: [stored], touching: [entity.startDate, entity.endDate])
        return .result()
    }
}
