import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlEntityItem {
    let id: String
    let entityId: String
    let serverId: String
    let name: String
    let icon: SFSymbolEntity
    let value: Bool
}

@available(iOS 18, *)
struct ControlLightsValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlLightsConfiguration) async throws -> ControlEntityItem {
        try await ControlRefreshDelay.wait()
        guard let serverId = configuration.light?.serverId,
              let lightId = configuration.light?.entityId,
              let state: String = try await ControlEntityProvider(domain: .light).currentState(
                  serverId: serverId,
                  entityId: lightId
              ) else {
            throw AppIntentError.restartPerform
        }
        let isOn = state == ControlEntityProvider.States.on.rawValue
        print(Date())
        print("isOn: \(isOn)")
        return item(light: configuration.light, value: isOn, iconName: configuration.icon)
    }

    func placeholder(for configuration: ControlLightsConfiguration) -> ControlEntityItem {
        item(light: configuration.light, value: nil, iconName: configuration.icon)
    }

    func previewValue(configuration: ControlLightsConfiguration) -> ControlEntityItem {
        item(light: configuration.light, value: nil, iconName: configuration.icon)
    }

    private func item(light: IntentLightEntity?, value: Bool?, iconName: SFSymbolEntity?) -> ControlEntityItem {
        let placeholder = placeholder(value: value)
        if let light {
            return .init(
                id: light.id,
                entityId: light.entityId,
                serverId: light.serverId,
                name: light.displayString,
                icon: iconName ?? .init(id: placeholder.iconName),
                value: value ?? false
            )
        } else {
            return .init(
                id: placeholder.id,
                entityId: placeholder.entityId,
                serverId: placeholder.serverId,
                name: placeholder.displayString,
                icon: .init(id: placeholder.iconName),
                value: false
            )
        }
    }

    private func placeholder(value: Bool?) -> IntentLightEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            displayString: L10n.Widgets.Controls.Light.placeholderTitle,
            iconName: (value ?? false) ? SFSymbol.lightbulbFill.rawValue : SFSymbol.lightbulb.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlLightsConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.lights.description", defaultValue: "Turn on/off Light")

    @Parameter(
        title: .init("app_intents.lights.light.title", defaultValue: "Light")
    )
    var light: IntentLightEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
