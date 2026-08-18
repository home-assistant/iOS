import AppIntents
import Foundation
import Shared

struct HACalendarEventAppEntityQuery: EntityQuery, EntityStringQuery {
    /// How far ahead the picker looks. Home Assistant only answers windowed queries, so suggestions
    /// need a bound; a month matches what the debug calendar screen fetches at a time.
    private static let suggestionWindow: TimeInterval = 30 * 24 * 60 * 60

    /// Identifiers are self-describing, so resolving never touches the network — see
    /// `HACalendarEventAppEntity`.
    func entities(for identifiers: [String]) async throws -> [HACalendarEventAppEntity] {
        identifiers.compactMap(HACalendarEventAppEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [HACalendarEventAppEntity] {
        await upcomingEvents().filter { $0.payload.summary.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [HACalendarEventAppEntity] {
        await upcomingEvents()
    }

    /// Upcoming events across every stored calendar, oldest first. Calendars are queried
    /// concurrently because each one is a separate REST call, the same way the frontend fans out.
    private func upcomingEvents() async -> [HACalendarEventAppEntity] {
        let calendars = HACalendar.all()
        guard !calendars.isEmpty else { return [] }

        let start = Current.date()
        let end = start.addingTimeInterval(Self.suggestionWindow)

        return await withTaskGroup(of: [HACalendarEventAppEntity].self) { group in
            for calendar in calendars {
                guard let server = Current.servers.server(forServerIdentifier: calendar.serverId) else { continue }
                group.addTask {
                    do {
                        let events = try await HomeAssistantAPI.calendarEvents(
                            server: server,
                            entityId: calendar.entityId,
                            start: start,
                            end: end
                        )
                        return events.compactMap { HACalendarEventAppEntity(event: $0, calendar: calendar) }
                    } catch {
                        Current.Log.error("Failed to fetch events for \(calendar.entityId), error: \(error)")
                        return []
                    }
                }
            }
            var results: [HACalendarEventAppEntity] = []
            for await events in group {
                results.append(contentsOf: events)
            }
            return results.sorted { $0.payload.start < $1.payload.start }
        }
    }
}
