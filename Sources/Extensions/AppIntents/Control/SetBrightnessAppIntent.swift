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

    #if os(watchOS)
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await .result(dialog: .init(stringLiteral: apply()))
    }
    #else
    // The card is app-only: the view and the entity it draws aren't built for the watch, where a
    // spoken answer is the whole interaction anyway.
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let dialog = try await apply()
        let state = await ControlResultSnippet.state(
            of: light,
            serverId: light.serverId,
            iconName: light.iconName,
            settlingOn: Domain.light.statesAfter(.turnOn)
        )
        return .result(dialog: .init(stringLiteral: dialog)) {
            if let state {
                ControlResultSnippetView(state: state)
            }
        }
    }
    #endif

    /// Sets the brightness, returning the sentence to speak.
    private func apply() async throws -> String {
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
        return L10n.AppIntents.Dialog.setBrightness(
            light.displayString,
            brightness
        )
    }
}
