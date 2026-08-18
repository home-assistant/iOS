import AppIntents
import Foundation
import Shared

/// Removes an event from a Home Assistant calendar. For a recurring series the scope decides
/// whether just the picked occurrence goes or everything from it onwards, matching the choice the
/// frontend prompts for before deleting.
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
            \.$event
            \.$scope
        }
    }

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
        let calendarId = ServerEntity.uniqueId(serverId: payload.serverId, entityId: payload.calendarEntityId)
        guard let stored = HACalendar.get(id: calendarId) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        guard stored.supports(.deleteEvent) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.deleteUnsupported(stored.name))
        }
        // Deleting addresses an event by its uid, and not every integration supplies one.
        guard let uid = payload.uid else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.eventNotDeletable(payload.summary))
        }
        guard let server = Current.servers.server(forServerIdentifier: payload.serverId),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        // The recurrence fields only mean anything for a series; sending them for a one-off event
        // makes Home Assistant reject the command.
        try await api.deleteCalendarEvent(
            entityId: payload.calendarEntityId,
            uid: uid,
            recurrenceId: payload.isRecurring ? payload.recurrenceId : nil,
            recurrenceRange: payload.isRecurring ? scope.recurrenceRange : nil
        )

        return .result(value: L10n.AppIntents.Calendar.DeleteEvent.responseSuccess(payload.summary, stored.name))
    }
}
