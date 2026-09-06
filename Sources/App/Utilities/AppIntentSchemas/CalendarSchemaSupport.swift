import AppIntents
import Foundation
import Shared

/// Lookups and validation shared by the calendar schema intents.
@available(iOS 27.0, *)
enum CalendarSchemaSupport {
    /// The stored calendar behind a schema entity, checked for the capability the caller needs.
    ///
    /// Home Assistant advertises `supported_features` per calendar, and a calendar that cannot do
    /// the thing rejects it server-side, so failing here gives the user something they can act on.
    static func calendar(for entity: CalendarSchemaEntity, requiring feature: HACalendar.Feature) throws -> HACalendar {
        guard let stored = HACalendar.get(id: entity.id) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        guard stored.supports(feature) else {
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
            throw ShortcutAppIntentError(
                editing
                    ? L10n.AppIntents.Calendar.Error.eventNotEditable(event.title)
                    : L10n.AppIntents.Calendar.Error.eventNotDeletable(event.title)
            )
        }
        return uid
    }

    static func api(for calendar: HACalendar) throws -> HomeAssistantAPI {
        guard let server = Current.servers.server(forServerIdentifier: calendar.serverId),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        return api
    }

    /// The end Home Assistant should store when the caller left it out: an hour later for a timed
    /// event, the same day for an all-day one, matching how the frontend opens a new event.
    static func resolvedEnd(_ end: Date?, start: Date, isAllDay: Bool) -> Date {
        if let end { return end }
        return isAllDay ? start : start.addingTimeInterval(60 * 60)
    }

    /// Home Assistant requires a timed event to have a strictly later end; an all-day event may
    /// start and end on the same day because the stored end is exclusive. Same rule as the
    /// frontend's `_isValidStartEnd`.
    static func validate(start: Date, end: Date, isAllDay: Bool) throws {
        if isAllDay {
            guard start <= end else {
                throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.invalidDuration)
            }
        } else {
            guard start < end else {
                throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.zeroDuration)
            }
        }
    }
}
