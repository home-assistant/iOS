import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlSwitchValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlSwitchConfiguration) async throws -> ControlEntityItem {
        try await ControlRefreshDelay.wait()
        guard let serverId = configuration.entity?.serverId,
              let switchId = configuration.entity?.entityId,
              let state = try await ControlEntityProvider(domains: [.switch]).currentState(
                  serverId: serverId,
                  entityId: switchId
              ) else {
            throw AppIntentError.restartPerform
        }

        let isOn = state == ControlEntityProvider.States.on.rawValue

        return item(entity: configuration.entity, value: isOn, iconName: configuration.icon)
    }

    func placeholder(for configuration: ControlSwitchConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.icon)
    }

    func previewValue(configuration: ControlSwitchConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.icon)
    }

    private func item(entity: IntentSwitchEntity?, value: Bool?, iconName: SFSymbolEntity?) -> ControlEntityItem {
        let placeholder = placeholder(value: value)
        if let entity {
            return .init(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                name: entity.displayString,
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
            displayString: L10n.Widgets.Controls.Switch.placeholderTitle,
            iconName: (value ?? false) ? SFSymbol.lightswitchOnFill.rawValue : SFSymbol.lightswitchOffFill.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlSwitchConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.switch.description",
        defaultValue: "Turn on/off switch"
    )

    @Parameter(
        title: .init("widgets.controls.switch.title", defaultValue: "Switch")
    )
    var entity: IntentSwitchEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
