import AppIntents
import Foundation
import Shared

/// Adds an event to a Home Assistant calendar, offering the fields from the frontend's event editor
/// (`dialog-calendar-event-editor.ts`): summary, description, location, all-day and start/end. The
/// editor's recurrence rule is left out — it needs a rule builder to be usable, and a raw RRULE
/// string is not something to ask for in a Shortcut.
@available(iOS 17.0, *)
struct CreateCalendarEventAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.calendar.create_event.title",
        defaultValue: "Add calendar event"
    )

    static var description = IntentDescription(.init(
        "app_intents.calendar.create_event.description",
        defaultValue: "Add an event to a Home Assistant calendar"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$calendar
            \.$summary
            \.$isAllDay
            \.$startDate
            \.$endDate
            \.$eventDescription
            \.$location
        }
    }

    @Parameter(title: .init("app_intents.calendar.entity.name", defaultValue: "Calendar"))
    var calendar: HACalendarAppEntity

    @Parameter(
        title: .init("app_intents.calendar.create_event.summary.title", defaultValue: "Title"),
        inputOptions: .init(capitalizationType: .sentences)
    )
    var summary: String

    @Parameter(
        title: .init("app_intents.calendar.create_event.all_day.title", defaultValue: "All-day"),
        default: false
    )
    var isAllDay: Bool

    @Parameter(
        title: .init("app_intents.calendar.create_event.start.title", defaultValue: "Starts"),
        kind: .dateTime
    )
    var startDate: Date

    @Parameter(
        title: .init("app_intents.calendar.create_event.end.title", defaultValue: "Ends"),
        kind: .dateTime
    )
    var endDate: Date

    @Parameter(
        title: .init("app_intents.calendar.create_event.event_description.title", defaultValue: "Description"),
        inputOptions: .init(capitalizationType: .sentences, multiline: true)
    )
    var eventDescription: String?

    @Parameter(
        title: .init("app_intents.calendar.create_event.location.title", defaultValue: "Location"),
        inputOptions: .init(capitalizationType: .sentences)
    )
    var location: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.refreshNetworkInformation()

        guard let stored = HACalendar.get(id: calendar.id) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.unknownCalendar)
        }
        // Home Assistant advertises per-entity capabilities; a calendar that can't create events
        // rejects the command server-side, so fail with something the user can act on instead.
        guard stored.supports(.createEvent) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.createUnsupported(stored.name))
        }
        guard startDate <= endDate else {
            throw ShortcutAppIntentError(L10n.AppIntents.Calendar.Error.invalidDuration)
        }
        guard let server = Current.servers.server(forServerIdentifier: stored.serverId),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        try await api.createCalendarEvent(
            entityId: stored.entityId,
            summary: summary,
            description: eventDescription,
            location: location,
            start: startDate,
            end: endDate,
            isAllDay: isAllDay
        )

        return .result(value: L10n.AppIntents.Calendar.CreateEvent.responseSuccess(summary, stored.name))
    }
}
