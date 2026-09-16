import AppIntents
import Foundation
import GRDB
import Shared

/// Answers from the cached calendar events, re-read from the server first: Home Assistant has no
/// "fetch event by id" endpoint, so the cache is what an identifier resolves against.
@available(iOS 27.0, *)
struct CalendarEventSchemaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CalendarEventSchemaEntity] {
        let wanted = Set(identifiers)
        return await events().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [CalendarEventSchemaEntity] {
        await events().filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [CalendarEventSchemaEntity] {
        await events()
    }

    private func events() async -> [CalendarEventSchemaEntity] {
        let calendars = CalendarSchemaSupport.exposedCalendars()
        await CalendarSchemaSupport.refreshCachedEvents(for: calendars)
        return await cachedEntities(for: calendars)
    }

    func cachedEntities() async -> [CalendarEventSchemaEntity] {
        await cachedEntities(for: CalendarSchemaSupport.exposedCalendars())
    }

    private func cachedEntities(for calendars: [HACalendar]) async -> [CalendarEventSchemaEntity] {
        let calendarsById = Dictionary(
            calendars.map { ("\($0.serverId)-\($0.entityId)", $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let records: [HACalendarEventRecord]
        do {
            records = try await Current.database().read { db in
                try HACalendarEventRecord
                    .order(Column(DatabaseTables.HACalendarEvent.start.rawValue).desc)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to read cached events for Siri: \(error.localizedDescription)")
            return []
        }

        return records.compactMap { record in
            guard let calendar = calendarsById["\(record.serverId)-\(record.calendarEntityId)"] else {
                return nil
            }
            return CalendarEventSchemaEntity(
                record: record,
                calendar: CalendarSchemaEntity(calendar: calendar)
            )
        }
    }
}
