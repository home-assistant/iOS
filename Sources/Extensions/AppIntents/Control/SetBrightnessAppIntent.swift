import AppIntents
import Foundation
import Shared

/// Dims or brightens a light. Home Assistant turns a light on when it is given a brightness.
@available(macOS 13.0, watchOS 9.4, *)
struct SetBrightnessAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.set_brightness.title",
        defaultValue: "Set brightness"
    )

    static let description = IntentDescription(.init(
        "app_intents.set_brightness.description",
        defaultValue: "Sets a light's brightness as a percentage"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$light) to \(\.$brightness)%")
    }

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var light: DimmableLightAppEntity

    @Parameter(
        title: .init("app_intents.set_brightness.parameter.brightness", defaultValue: "Brightness"),
        inclusiveRange: (1, 100)
    )
    var brightness: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: light.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        try await AppIntentServerAPI.callAction(
            server: server,
            domain: Domain.light.rawValue,
            service: Service.turnOn.rawValue,
            data: ["entity_id": light.entityId, "brightness_pct": brightness],
            returnResponse: false
        )
        return .result(dialog: .init(stringLiteral: L10n.AppIntents.Dialog.setBrightness(
            light.displayString,
            brightness
        )))
    }
}
