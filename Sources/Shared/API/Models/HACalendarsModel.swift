import Foundation
import HAKit

public protocol HACalendarsModelProtocol {
    /// Rebuilds the stored calendars for `server` from an already-fetched `/states` payload.
    func updateModel(_ entities: [HAEntity], server: Server) async
    /// Fetches `/states` and rebuilds the stored calendars for `server`.
    /// Returns `false` when the server could not be reached or the write failed.
    @discardableResult
    func refresh(server: Server) async -> Bool
    /// Live events for `calendar` in `[start, end)`, cached as a side effect.
    func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent]
}

/// Derives the `HACalendar` rows from the entity states, mirroring the frontend's `getCalendars`
/// (`src/data/calendar.ts`): every `calendar.*` entity that has a state, isn't `unavailable`, and
/// isn't hidden in the entity registry, sorted by entity id.
///
/// The frontend colors each calendar from the entity registry's `options.calendar.color` and falls
/// back to `getColorByIndex`. The app fetches the registry through
/// `config/entity_registry/list_for_display`, which does not carry entity options, so only the
/// index-based fallback is available here — the same palette, in the same order, so the colors line
/// up with the frontend for every calendar the user hasn't recolored.
final class HACalendarsModel: HACalendarsModelProtocol {
    static var shared: HACalendarsModelProtocol = HACalendarsModel()

    private static let calendarDomain = "calendar"

    func updateModel(_ entities: [HAEntity], server: Server) async {
        let serverId = server.identifier.rawValue
        let registryRows = (try? EntityRegistryListForDisplay.Entity.config(serverId: serverId)) ?? []
        let registryNames: [String: String] = Dictionary(
            registryRows.compactMap { row in row.name.map { (row.entityId, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let hiddenEntityIds = Set(registryRows.filter(\.isHidden).map(\.entityId))

        let calendars = entities
            .filter { entity in
                entity.domain == Self.calendarDomain
                    && entity.state != "unavailable"
                    && !hiddenEntityIds.contains(entity.entityId)
            }
            .sorted(by: { $0.entityId < $1.entityId })
            .enumerated()
            .map { index, entity in
                HACalendar(
                    id: ServerEntity.uniqueId(serverId: serverId, entityId: entity.entityId),
                    serverId: serverId,
                    entityId: entity.entityId,
                    name: registryNames[entity.entityId] ?? entity.attributes.friendlyName ?? entity.entityId,
                    backgroundColor: HACalendar.defaultColor(at: index),
                    supportedFeatures: (entity.attributes.dictionary["supported_features"] as? Int) ?? 0,
                    sortOrder: index
                )
            }

        Current.Log.verbose(
            "Found \(calendars.count) calendars for server \(server.info.name) out of \(entities.count) entities"
        )
        await HACalendar.replaceAll(calendars, serverId: serverId)
    }

    @discardableResult
    func refresh(server: Server) async -> Bool {
        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to refresh calendars for \(server.info.name)")
            return false
        }

        let entities: [HAEntity]? = await withCheckedContinuation { continuation in
            api.connection.send(HATypedRequest<[HAEntity]>.fetchStates()) { result in
                switch result {
                case let .success(entities):
                    continuation.resume(returning: entities)
                case let .failure(error):
                    Current.Log.error("Failed to fetch states while refreshing calendars: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let entities else { return false }
        await updateModel(entities, server: server)
        return true
    }

    /// Reads a calendar's events straight from the server and refreshes the cache with what came
    /// back. The cache is only read when the fetch fails, so callers always get live data when the
    /// server is reachable and the last known events when it isn't.
    func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
        guard let server = Current.servers.server(forServerIdentifier: calendar.serverId) else {
            Current.Log.error("No server for calendar \(calendar.entityId), reading cached events")
            return await cachedEvents(for: calendar, start: start, end: end)
        }

        do {
            let events = try await HomeAssistantAPI.calendarEvents(
                server: server,
                entityId: calendar.entityId,
                start: start,
                end: end
            )
            await HACalendarEventRecord.replace(
                events.map { $0.record(for: calendar) },
                serverId: calendar.serverId,
                calendarEntityId: calendar.entityId,
                start: start,
                end: end
            )
            return events
        } catch {
            Current.Log.error("Failed to fetch events for \(calendar.entityId), falling back to cache: \(error)")
            return await cachedEvents(for: calendar, start: start, end: end)
        }
    }

    private func cachedEvents(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
        await HACalendarEventRecord.events(
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            start: start,
            end: end
        ).map(\.event)
    }
}

extension HACalendarEvent {
    func record(for calendar: HACalendar) -> HACalendarEventRecord {
        .init(
            id: HACalendarEventRecord.uniqueId(
                serverId: calendar.serverId,
                calendarEntityId: calendar.entityId,
                uid: uid,
                recurrenceId: recurrenceId,
                start: start
            ),
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            uid: uid,
            recurrenceId: recurrenceId,
            summary: summary,
            start: start,
            end: end,
            isAllDay: isAllDay,
            eventDescription: description,
            location: location,
            rrule: rrule
        )
    }
}

extension HACalendarEventRecord {
    var event: HACalendarEvent {
        .init(
            summary: summary,
            start: start,
            end: end,
            isAllDay: isAllDay,
            description: eventDescription,
            location: location,
            uid: uid,
            recurrenceId: recurrenceId,
            rrule: rrule
        )
    }
}
