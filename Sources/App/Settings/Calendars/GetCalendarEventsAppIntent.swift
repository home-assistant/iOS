import AppIntents
import Foundation
import Shared

/// Lists the events on a Home Assistant calendar between two dates.
///
/// The result is the same entity the delete intent takes, so a Shortcut can read a calendar and act
/// on what it finds without an intermediate step.
@available(iOS 17.0, *)
struct GetCalendarEventsAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.calendar.get_events.title",
        defaultValue: "Get calendar events"
    )

    static var description = IntentDescription(.init(
        "app_intents.calendar.get_events.description",
        defaultValue: "Get the events on a Home Assistant calendar between two dates"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$calendar
            \.$startDate
            \.$endDate
        }
    }

    @Parameter(title: .init("app_intents.calendar.entity.name", defaultValue: "Calendar"))
    var calendar: HACalendarAppEntity

    @Parameter(title: .init("app_intents.calendar.get_events.start.title", defaultValue: "From"))
    var startDate: Date

    @Parameter(title: .init("app_intents.calendar.get_events.end.title", defaultValue: "To"))
    var endDate: Date

    func perform() async throws -> some IntentResult & ReturnsValue<[HACalendarEventAppEntity]> {
        await Current.connectivity.refreshNetworkInformation()

        guard let stored = HACalendar.get(id: calendar.id) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        guard startDate <= endDate else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.invalidDuration)
        }
        guard let server = Current.servers.server(forServerIdentifier: stored.serverId) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        // Reading needs no capability check: `supported_features` only gates creating, updating and
        // deleting, every calendar entity can be queried.
        let events = try await HomeAssistantAPI.calendarEvents(
            server: server,
            entityId: stored.entityId,
            start: startDate,
            end: endDate
        )

        return .result(value: events.compactMap { HACalendarEventAppEntity(event: $0, calendar: stored) })
    }
}
