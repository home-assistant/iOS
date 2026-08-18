import AppIntents
import Foundation
import Shared

/// Offers the stored calendars grouped into one section per server, so a picker with several
/// servers onboarded shows which server each calendar belongs to instead of one flat list where
/// identically named calendars are indistinguishable.
struct HACalendarAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HACalendarAppEntity] {
        identifiers.compactMap { identifier in
            HACalendar.get(id: identifier).map(HACalendarAppEntity.init(calendar:))
        }
    }

    /// Matches the calendar's display name as well as its entity id, so both "Family" and
    /// "calendar.family" resolve.
    func entities(matching string: String) async throws -> IntentItemCollection<HACalendarAppEntity> {
        groupedByServer(HACalendar.all().filter { calendar in
            calendar.name.localizedCaseInsensitiveContains(string)
                || calendar.entityId.localizedCaseInsensitiveContains(string)
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<HACalendarAppEntity> {
        groupedByServer(HACalendar.all())
    }

    /// `HACalendar.all()` is already ordered by server and then by the frontend's calendar order, so
    /// the sections keep that order rather than re-sorting.
    private func groupedByServer(_ calendars: [HACalendar]) -> IntentItemCollection<HACalendarAppEntity> {
        var order: [String] = []
        var byServer: [String: [HACalendar]] = [:]
        for calendar in calendars {
            if byServer[calendar.serverId] == nil {
                order.append(calendar.serverId)
            }
            byServer[calendar.serverId, default: []].append(calendar)
        }

        return IntentItemCollection(sections: order.map { serverId in
            // A calendar can outlive the server row it came from (the rows are only rewritten on the
            // next database update), so fall back to the identifier rather than dropping the section.
            let name = Current.servers.server(forServerIdentifier: serverId)?.info.name ?? serverId
            return IntentItemSection(
                .init(stringLiteral: name),
                items: (byServer[serverId] ?? []).map(HACalendarAppEntity.init(calendar:))
            )
        })
    }
}
