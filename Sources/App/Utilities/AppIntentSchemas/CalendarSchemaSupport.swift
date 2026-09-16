import AppIntents
import Foundation
import Shared

/// Lookups and validation shared by the calendar schema intents.
@available(iOS 27.0, *)
enum CalendarSchemaSupport {
    /// The calendars Siri may offer, honouring the per-server opt-out.
    ///
    /// The schema queries and the event Spotlight index read through this, the same way
    /// `ControlEntityProvider.getEntitiesExposedToSiri()` covers entities. The rest of the app keeps
    /// seeing every calendar: the setting is about what is offered to Siri, not about hiding a
    /// server from the app.
    static func exposedCalendars() -> [HACalendar] {
        let hiddenServers = SiriServerExposure.hiddenServerIds()
        let hiddenCalendars = SiriEntityExposure.hiddenEntityIds(domain: Domain.calendar.rawValue)
        guard !hiddenServers.isEmpty || !hiddenCalendars.isEmpty else {
            return HACalendar.all()
        }
        return HACalendar.all().filter { !hiddenServers.contains($0.serverId) && !hiddenCalendars.contains($0.id) }
    }

    static func defaultCalendar() -> HACalendar? {
        let defaults = SiriEntityExposure.defaultEntityIds(domain: Domain.calendar.rawValue)
        guard !defaults.isEmpty else { return nil }
        return exposedCalendars().first { defaults.contains($0.id) }
    }

    /// One calendar by id, or nil when its server is opted out, so an identifier saved before the
    /// opt-out stops resolving rather than quietly still working.
    static func exposedCalendar(id: String) -> HACalendar? {
        guard let calendar = HACalendar.get(id: id) else { return nil }
        if SiriServerExposure.hiddenServerIds().contains(calendar.serverId) { return nil }
        if SiriEntityExposure.hiddenEntityIds(domain: Domain.calendar.rawValue).contains(calendar.id) { return nil }
        return calendar
    }

    /// The stored calendar behind a schema entity, checked for the capability the caller needs.
    ///
    /// Home Assistant advertises `supported_features` per calendar, and a calendar that cannot do
    /// the thing rejects it server-side, so failing here gives the user something they can act on.
    static func calendar(for entity: CalendarSchemaEntity, requiring feature: HACalendar.Feature) throws -> HACalendar {
        guard let stored = exposedCalendar(id: entity.id) else {
            Current.Log.error("Calendar \(entity.id) is not in the database or is not exposed to Siri")
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        guard stored.supports(feature) else {
            Current.Log.error("Calendar \(stored.entityId) does not support \(feature)")
            throw ShortcutAppIntentError(Self.unsupported(feature, calendar: stored.name))
        }
        return stored
    }

    private static func unsupported(_ feature: HACalendar.Feature, calendar: String) -> String {
        switch feature {
        case .createEvent: L10n.AppIntents.Calendar.Error.createUnsupported(calendar)
        case .updateEvent: L10n.AppIntents.Calendar.Error.updateUnsupported(calendar)
        case .deleteEvent: L10n.AppIntents.Calendar.Error.deleteUnsupported(calendar)
        }
    }

    /// The identifier Home Assistant addresses an event by. Integrations that don't supply one
    /// produce events that can be listed but not changed, so this refuses rather than guessing.
    static func uid(of event: CalendarEventSchemaEntity, editing: Bool) throws -> String {
        guard let uid = event.uid?.nilIfEmpty else {
            Current.Log.error("Event \(event.id) has no uid, so it cannot be edited or deleted")
            throw ShortcutAppIntentError(
                editing
                    ? L10n.AppIntents.Calendar.Error.eventNotEditable(event.title)
                    : L10n.AppIntents.Calendar.Error.eventNotDeletable(event.title)
            )
        }
        return uid
    }

    static let refreshWindow: TimeInterval = 30 * 24 * 60 * 60

    static func refreshCachedEvents(for calendars: [HACalendar], touching dates: [Date] = []) async {
        guard !calendars.isEmpty else { return }
        let now = Current.date()
        let day: TimeInterval = 24 * 60 * 60
        let start = min(now.addingTimeInterval(-refreshWindow), (dates.min() ?? now).addingTimeInterval(-day))
        let end = max(now.addingTimeInterval(refreshWindow), (dates.max() ?? now).addingTimeInterval(day))

        await withTaskGroup(of: Void.self) { group in
            for calendar in calendars {
                group.addTask {
                    _ = await Current.calendarsModel().events(for: calendar, start: start, end: end)
                }
            }
        }
    }

    static func cachedEvent(
        on calendar: HACalendar,
        titled summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        uid: String? = nil,
        excluding knownIds: Set<String> = []
    ) async -> HACalendarEventRecord? {
        let matches = await cachedEvents(
            on: calendar,
            titled: summary,
            start: start,
            end: end,
            isAllDay: isAllDay,
            uid: uid
        )
        let unseen = matches.filter { !knownIds.contains($0.id) }
        if unseen.count == 1 {
            return unseen[0]
        }
        return matches.count == 1 ? matches[0] : nil
    }

    static func cachedEvents(
        on calendar: HACalendar,
        titled summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        uid: String? = nil
    ) async -> [HACalendarEventRecord] {
        var windowStart = start
        var windowEnd = end
        if isAllDay {
            let days = Calendar.current
            windowStart = days.startOfDay(for: start)
            windowEnd = days.date(byAdding: .day, value: 1, to: days.startOfDay(for: end)) ?? end
        }
        let records = await HACalendarEventRecord.events(
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            start: windowStart,
            end: windowEnd
        )
        return records.filter { record in
            if let uid, record.uid != uid {
                return false
            }
            guard record.summary == summary, record.isAllDay == isAllDay else { return false }
            if isAllDay {
                return Calendar.current.isDate(record.start, inSameDayAs: start)
            }
            return abs(record.start.timeIntervalSince(start)) < 1
        }
    }

    static func api(for calendar: HACalendar) throws -> HomeAssistantAPI {
        guard let server = Current.servers.server(forServerIdentifier: calendar.serverId),
              let api = Current.api(for: server) else {
            Current.Log.error("No API for server \(calendar.serverId), which owns \(calendar.entityId)")
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        return api
    }

    /// The end Home Assistant should store when the caller left it out: an hour later for a timed
    /// event, the same day for an all-day one, matching how the frontend opens a new event.
    static func resolvedEnd(_ end: Date?, start: Date, isAllDay: Bool) -> Date {
        if let end {
            return end
        }
        return isAllDay ? start : start.addingTimeInterval(60 * 60)
    }

    /// Home Assistant requires a timed event to have a strictly later end; an all-day event may
    /// start and end on the same day because the stored end is exclusive. Same rule as the
    /// frontend's `_isValidStartEnd`.
    static func validate(start: Date, end: Date, isAllDay: Bool) throws {
        if isAllDay {
            guard start <= end else {
                Current.Log.error("All-day event ends (\(end)) before it starts (\(start))")
                throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.invalidDuration)
            }
        } else {
            guard start < end else {
                Current.Log.error("Event ends (\(end)) at or before it starts (\(start))")
                throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.zeroDuration)
            }
        }
    }
}
