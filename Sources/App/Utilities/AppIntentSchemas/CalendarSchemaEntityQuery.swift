import AppIntents
import Foundation
import Shared

@available(iOS 27.0, *)
struct CalendarSchemaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CalendarSchemaEntity] {
        identifiers.compactMap {
            CalendarSchemaSupport.exposedCalendar(id: $0).map(CalendarSchemaEntity.init(calendar:))
        }
    }

    func entities(matching string: String) async throws -> [CalendarSchemaEntity] {
        CalendarSchemaSupport.exposedCalendars()
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
                    || $0.entityId.localizedCaseInsensitiveContains(string)
            }
            .map(CalendarSchemaEntity.init(calendar:))
    }

    func suggestedEntities() async throws -> [CalendarSchemaEntity] {
        CalendarSchemaSupport.exposedCalendars().map(CalendarSchemaEntity.init(calendar:))
    }

    func defaultResult() async -> CalendarSchemaEntity? {
        CalendarSchemaSupport.defaultCalendar().map(CalendarSchemaEntity.init(calendar:))
    }
}
