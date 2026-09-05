import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct LightIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.light.title", defaultValue: "Control light")

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var light: IntentLightEntity

    @Parameter(title: .init("app_intents.state.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result(dialog: .init(stringLiteral: L10n.AppIntents.Error.noServer))
        }

        var service = Service.toggle.rawValue
        if !toggle {
            service = value ? Service.turnOn.rawValue : Service.turnOff.rawValue
        }

        do {
            try await connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": light.entityId,
                ]
            )).promise.async()
        } catch {
            throw ShortcutAppIntentError(error.localizedDescription)
        }
        return .result(dialog: .init(stringLiteral: OnOffIntentDialog.text(
            entityName: light.displayString,
            toggle: toggle,
            value: value
        )))
    }
}
