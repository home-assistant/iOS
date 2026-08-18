import AppIntents
import Foundation
import Shared

struct HACalendarAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HACalendarAppEntity] {
        identifiers.compactMap { identifier in
            HACalendar.get(id: identifier).map(HACalendarAppEntity.init(calendar:))
        }
    }

    /// Matches the calendar's display name as well as its entity id, so both "Family" and
    /// "calendar.family" resolve.
    func entities(matching string: String) async throws -> [HACalendarAppEntity] {
        HACalendar.all()
            .filter { calendar in
                calendar.name.localizedCaseInsensitiveContains(string)
                    || calendar.entityId.localizedCaseInsensitiveContains(string)
            }
            .map(HACalendarAppEntity.init(calendar:))
    }

    func suggestedEntities() async throws -> [HACalendarAppEntity] {
        HACalendar.all().map(HACalendarAppEntity.init(calendar:))
    }
}
