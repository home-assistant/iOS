import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct HACalendarEventAppEntityQuery: EntityQuery, EntityStringQuery {
    /// How far ahead the picker looks. Home Assistant only answers windowed queries, so the options
    /// need a bound; a month matches what the debug calendar screen fetches at a time.
    private static let suggestionWindow: TimeInterval = 30 * 24 * 60 * 60

    /// Scopes the options to the calendar already chosen in the delete action, so the picker offers
    /// that calendar's events rather than everything the user has. Unresolved when the query runs
    /// outside that action, in which case every calendar is searched.
    @IntentParameterDependency<DeleteCalendarEventAppIntent>(\.$calendar)
    private var deleteEvent

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

    /// Upcoming events, oldest first. Calendars are queried concurrently because each one is a
    /// separate REST call, the same way the frontend fans out. Each fetch also refreshes the cache,
    /// so the picker still offers something when the server is unreachable.
    private func upcomingEvents() async -> [HACalendarEventAppEntity] {
        let calendars = scopedCalendars()
        guard !calendars.isEmpty else { return [] }

        let start = Current.date()
        let end = start.addingTimeInterval(Self.suggestionWindow)

        return await withTaskGroup(of: [HACalendarEventAppEntity].self) { group in
            for calendar in calendars {
                group.addTask {
                    let events = await Current.calendarsModel().events(for: calendar, start: start, end: end)
                    return events.compactMap { HACalendarEventAppEntity(event: $0, calendar: calendar) }
                }
            }
            var results: [HACalendarEventAppEntity] = []
            for await events in group {
                results.append(contentsOf: events)
            }
            return results.sorted { $0.payload.start < $1.payload.start }
        }
    }

    private func scopedCalendars() -> [HACalendar] {
        guard let chosen = deleteEvent?.calendar, let calendar = HACalendar.get(id: chosen.id) else {
            return HACalendar.all()
        }
        return [calendar]
    }
}
