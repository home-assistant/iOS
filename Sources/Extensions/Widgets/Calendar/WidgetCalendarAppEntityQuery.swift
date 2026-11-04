import AppIntents
import Foundation
import Shared

/// Offers the stored calendars for the widget's calendar picker, one section per server.
///
/// Deliberately not scoped to a server parameter: the widget merges events from any number of
/// calendars, and a household with two servers onboarded has no reason to be forced into picking
/// one of them first.
@available(iOS 17.0, *)
struct WidgetCalendarAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetCalendarAppEntity] {
        identifiers.compactMap { identifier in
            HACalendar.get(id: identifier).map(WidgetCalendarAppEntity.init(calendar:))
        }
    }

    /// Matches the display name as well as the entity id, so both "Family" and "calendar.family"
    /// resolve.
    func entities(matching string: String) async throws -> IntentItemCollection<WidgetCalendarAppEntity> {
        groupedByServer(HACalendar.all().filter { calendar in
            calendar.name.localizedCaseInsensitiveContains(string)
                || calendar.entityId.localizedCaseInsensitiveContains(string)
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetCalendarAppEntity> {
        groupedByServer(HACalendar.all())
    }

    /// `HACalendar.all()` already comes back ordered by server and then by the frontend's calendar
    /// order, so the sections keep that order rather than re-sorting.
    private func groupedByServer(_ calendars: [HACalendar]) -> IntentItemCollection<WidgetCalendarAppEntity> {
        var order: [String] = []
        var byServer: [String: [HACalendar]] = [:]
        for calendar in calendars {
            if byServer[calendar.serverId] == nil {
                order.append(calendar.serverId)
            }
            byServer[calendar.serverId, default: []].append(calendar)
        }

        return IntentItemCollection(sections: order.map { serverId in
            // A calendar can outlive the server row it came from, so fall back to the identifier
            // rather than dropping the whole section.
            let name = Current.servers.server(forServerIdentifier: serverId)?.info.name ?? serverId
            return IntentItemSection(
                .init(stringLiteral: name),
                items: (byServer[serverId] ?? []).map(WidgetCalendarAppEntity.init(calendar:))
            )
        })
    }
}
