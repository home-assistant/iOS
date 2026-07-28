import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct FireEventAppIntent: AppIntent, CustomIntentMigratedAppIntent {
    // Carries over shortcuts built with the deprecated SiriKit FireEventIntent
    static let intentClassName = "FireEventIntent"

    static var title: LocalizedStringResource = .init(
        "app_intents.fire_event.title",
        defaultValue: "Fire event"
    )

    static var description = IntentDescription(.init(
        "app_intents.fire_event.description",
        defaultValue: "Fire an event on a Home Assistant server"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$eventName
            \.$eventData
        }
    }

    @Parameter(title: .init("app_intents.server.title", defaultValue: "Server"))
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("app_intents.fire_event.event_name.title", defaultValue: "Event name"),
        inputOptions: .init(
            capitalizationType: .none,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var eventName: String

    @Parameter(
        title: .init("app_intents.fire_event.event_data.title", defaultValue: "Event data"),
        description: .init(
            "app_intents.fire_event.event_data.description",
            defaultValue: "JSON data to send with the event"
        ),
        default: "{}",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var eventData: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = server.getServer(),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let (eventType, eventDataDict) = try Self.event(name: eventName, payload: eventData)
        try await api.CreateEvent(eventType: eventType, eventData: eventDataDict).async()
        return .result(value: L10n.AppIntents.FireEvent.responseSuccess(eventType))
    }

    // The payload may be the raw event data dictionary, or wrap it in an "eventData" key
    // (optionally overriding the event name via "eventName"), matching what the
    // deprecated SiriKit FireEventIntentHandler accepted so migrated shortcuts keep working.
    private static func event(name: String, payload: String) throws -> (String, [String: Any]) {
        guard payload.isEmpty == false else { return (name, [:]) }

        guard let jsonObject = try? JSONSerialization.jsonObject(
            with: Data(payload.utf8),
            options: .allowFragments
        ) as? [String: Any] else {
            throw ShortcutAppIntentError(L10n.AppIntents.FireEvent.Error.invalidPayload)
        }

        var eventName = name
        var eventDataDict: [String: Any] = [:]
        var isGenericPayload = true

        if let wrappedName = jsonObject["eventName"] as? String {
            eventName = wrappedName
            isGenericPayload = false
        }

        if let wrappedData = jsonObject["eventData"] as? [String: Any] {
            eventDataDict = wrappedData
            isGenericPayload = false
        }

        if isGenericPayload {
            eventDataDict = jsonObject
        }

        return (eventName, eventDataDict)
    }
}
