import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct PerformActionAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.perform_action.title",
        defaultValue: "Perform action"
    )

    static var description = IntentDescription(.init(
        "app_intents.perform_action.description",
        defaultValue: "Perform an action on a Home Assistant server"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$action
            \.$payload
        }
    }

    @Parameter(title: .init("app_intents.server.title", defaultValue: "Server"))
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("app_intents.perform_action.action.title", defaultValue: "Action"),
        requestValueDialog: IntentDialog(.init(
            "app_intents.perform_action.action_parameter_configuration",
            defaultValue: "Which action?"
        ))
    )
    var action: IntentActionEntity

    @Parameter(
        title: .init("app_intents.perform_action.payload.title", defaultValue: "Action data"),
        description: .init(
            "app_intents.perform_action.payload.description",
            defaultValue: "JSON data to send with the action"
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
    var payload: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.syncNetworkInformation()
        guard action.serverId == server.id,
              let server = server.getServer(),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let payloadDict = try Self.payloadDictionary(from: payload)
        let components = action.actionId.split(separator: ".")
        guard components.count == 2 else {
            throw ShortcutAppIntentError(L10n.AppIntents.PerformAction.Error.invalidAction)
        }

        do {
            let response = try await api.callServiceWithResponse(
                domain: String(components[0]),
                service: String(components[1]),
                serviceData: payloadDict,
                returnResponse: action.supportsResponse
            ).async()

            if let json = response.jsonString() {
                return .result(value: json)
            }
        } catch {
            throw ShortcutAppIntentError(L10n.AppIntents.PerformAction.responseFailure(error.localizedDescription))
        }

        return .result(value: L10n.AppIntents.PerformAction.responseSuccess)
    }

    private static func payloadDictionary(from payload: String) throws -> [String: Any] {
        guard payload.isEmpty == false else { return [:] }

        let data = Data(payload.utf8)
        guard let jsonObject = try JSONSerialization.jsonObject(
            with: data,
            options: .allowFragments
        ) as? [String: Any] else {
            throw ShortcutAppIntentError(L10n.AppIntents.PerformAction.Error.invalidPayload)
        }

        return jsonObject
    }
}
