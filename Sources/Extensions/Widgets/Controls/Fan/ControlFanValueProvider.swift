import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlFanValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlFanConfiguration) async throws -> ControlEntityItem {
        try await ControlRefreshDelay.wait()
        guard let serverId = configuration.fan?.serverId,
              let fanId = configuration.fan?.entityId,
              let state: String = try await ControlEntityProvider(domains: [.fan]).currentState(
                  serverId: serverId,
                  entityId: fanId
              ) else {
            throw AppIntentError.restartPerform
        }
        let isOn = state == ControlEntityProvider.States.on.rawValue
        let icon = isOn ? configuration.icon : configuration.offStateIcon
        return item(fan: configuration.fan, value: isOn, iconName: icon)
    }

    func placeholder(for configuration: ControlFanConfiguration) -> ControlEntityItem {
        item(fan: configuration.fan, value: nil, iconName: configuration.icon)
    }

    func previewValue(configuration: ControlFanConfiguration) -> ControlEntityItem {
        item(fan: configuration.fan, value: nil, iconName: configuration.icon)
    }

    private func item(fan: IntentFanEntity?, value: Bool?, iconName: SFSymbolEntity?) -> ControlEntityItem {
        let placeholder = placeholder(value: value)
        if let fan {
            return .init(
                id: fan.id,
                entityId: fan.entityId,
                serverId: fan.serverId,
                name: fan.displayString,
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

    private func placeholder(value: Bool?) -> IntentFanEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            displayString: L10n.Widgets.Controls.Fan.placeholderTitle,
            iconName: (value ?? false) ? SFSymbol.fanFill.rawValue : SFSymbol.fan.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlFanConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.fan.description",
        defaultValue: "Turn on/off your fan"
    )

    @Parameter(
        title: .init("app_intents.fan.title", defaultValue: "Fan")
    )
    var fan: IntentFanEntity?
    @Parameter(
        title: .init("app_intents.fan.on_state_icon.title", defaultValue: "Icon for on state"),
        default: SFSymbolEntity(id: SFSymbol.fanFill.rawValue)
    )
    var icon: SFSymbolEntity?
    @Parameter(
        title: .init("app_intents.fan.off_state_icon.title", defaultValue: "Icon for off state"),
        default: SFSymbolEntity(id: SFSymbol.fan.rawValue)
    )
    var offStateIcon: SFSymbolEntity?
}
