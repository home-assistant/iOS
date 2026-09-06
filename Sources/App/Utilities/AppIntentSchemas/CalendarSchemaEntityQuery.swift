import AppIntents
import Foundation
import Shared

@available(iOS 27.0, *)
struct CalendarSchemaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CalendarSchemaEntity] {
        identifiers.compactMap { HACalendar.get(id: $0).map(CalendarSchemaEntity.init(calendar:)) }
    }

    func entities(matching string: String) async throws -> [CalendarSchemaEntity] {
        HACalendar.all()
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
                    || $0.entityId.localizedCaseInsensitiveContains(string)
            }
            .map(CalendarSchemaEntity.init(calendar:))
    }

    func suggestedEntities() async throws -> [CalendarSchemaEntity] {
        HACalendar.all().map(CalendarSchemaEntity.init(calendar:))
    }
}
