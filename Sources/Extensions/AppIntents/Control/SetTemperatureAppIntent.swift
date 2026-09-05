import AppIntents
import Foundation
import Shared

/// Sets a thermostat's target temperature, in whatever unit the server is configured for.
@available(macOS 13.0, watchOS 9.4, *)
struct SetTemperatureAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.set_temperature.title",
        defaultValue: "Set temperature"
    )

    static let description = IntentDescription(.init(
        "app_intents.set_temperature.description",
        defaultValue: "Sets a thermostat's target temperature, in the unit your server uses"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$entity) to \(\.$temperature)")
    }

    @Parameter(title: .init("app_intents.set_temperature.parameter.entity", defaultValue: "Thermostat"))
    var entity: ThermostatAppEntity

    /// Bounded so a slip of the tongue cannot ask for something absurd. The literals mirror
    /// `ClimateControlState.defaultMinTemperature` and `defaultMaxTemperature`, which App Intents
    /// cannot reference here because the range must be a compile-time constant; a test pins them.
    @Parameter(
        title: .init("app_intents.set_temperature.parameter.temperature", defaultValue: "Temperature"),
        inclusiveRange: (7, 35)
    )
    var temperature: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: entity.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        try await AppIntentServerAPI.callAction(
            server: server,
            domain: Domain.climate.rawValue,
            service: Service.setTemperature.rawValue,
            data: ["entity_id": entity.entityId, "temperature": temperature],
            returnResponse: false
        )
        return .result(dialog: .init(stringLiteral: L10n.AppIntents.Dialog.setTemperature(
            entity.displayString,
            NumberFormatter.localizedString(from: NSNumber(value: temperature), number: .decimal)
        )))
    }
}
