import AppIntents
import Foundation
import Shared

/// Removes an event from a Home Assistant calendar.
///
/// The calendar is picked first so the event picker only offers that calendar's events, and events
/// can be searched by name. An event produced by `GetCalendarEventsAppIntent` can be passed straight
/// in, since both actions speak the same entity.
///
/// For a recurring series the scope decides whether just the picked occurrence goes or everything
/// from it onwards, matching the choice the frontend prompts for before deleting.
@available(iOS 17.0, *)
struct DeleteCalendarEventAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.calendar.delete_event.title",
        defaultValue: "Delete calendar event"
    )

    static var description = IntentDescription(.init(
        "app_intents.calendar.delete_event.description",
        defaultValue: "Delete an event from a Home Assistant calendar"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$calendar
            \.$event
            \.$scope
        }
    }

    @Parameter(title: .init("app_intents.calendar.entity.name", defaultValue: "Calendar"))
    var calendar: HACalendarAppEntity

    @Parameter(title: .init("app_intents.calendar.event.entity.name", defaultValue: "Calendar event"))
    var event: HACalendarEventAppEntity

    @Parameter(
        title: .init("app_intents.calendar.delete_event.scope.title", defaultValue: "Delete"),
        default: CalendarEventDeleteScopeAppEnum.thisEvent
    )
    var scope: CalendarEventDeleteScopeAppEnum

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.refreshNetworkInformation()

        let payload = event.payload
        guard let stored = HACalendar.get(id: calendar.id) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        // An event carries the calendar it came from, so a piped-in event can disagree with the
        // calendar chosen here. Deleting from the wrong one would silently do nothing useful, so say
        // so rather than guessing which the user meant.
        guard payload.serverId == stored.serverId, payload.calendarEntityId == stored.entityId else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.eventNotInCalendar(
                payload.summary,
                stored.name
            ))
        }
        guard stored.supports(.deleteEvent) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.deleteUnsupported(stored.name))
        }
        // Deleting addresses an event by its uid, and not every integration supplies one.
        guard let uid = payload.uid else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.eventNotDeletable(payload.summary))
        }
        guard let server = Current.servers.server(forServerIdentifier: stored.serverId),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        // The recurrence fields only mean anything for a series; sending them for a one-off event
        // makes Home Assistant reject the command.
        try await api.deleteCalendarEvent(
            entityId: stored.entityId,
            uid: uid,
            recurrenceId: payload.isRecurring ? payload.recurrenceId : nil,
            recurrenceRange: payload.isRecurring ? scope.recurrenceRange : nil
        )

        return .result(value: L10n.AppIntents.Calendar.DeleteEvent.responseSuccess(payload.summary, stored.name))
    }
}
