import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenSwitchItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenSwitchValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenSwitchConfiguration) async throws -> ControlOpenSwitchItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenSwitchConfiguration) -> ControlOpenSwitchItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenSwitchConfiguration) -> ControlOpenSwitchItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenSwitchConfiguration) -> ControlOpenSwitchItem {
        .init(
            entity: configuration.entity ?? .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: "",
                iconName: ""
            ),
            icon: configuration.icon ?? placeholder().icon
        )
    }

    private func placeholder() -> ControlOpenSwitchItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.powerplugOutline.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenSwitchConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_switch.configuration.title",
        defaultValue: "Open Switch"
    )

    @Parameter(
        title: .init("widgets.controls.open_switch.configuration.parameter.entity", defaultValue: "Switch"),
        optionsProvider: SwitchEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct SwitchEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.switch]).getEntities()

        return .init(sections: entities.map { (key: Server, value: [ControlEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.map { entity in
                    HAAppEntityAppIntentEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        serverName: key.info.name,
                        displayString: entity.name,
                        iconName: entity.icon ?? SFSymbol.powerplugOutline.rawValue
                    )
                }
            )
        })
    }
}
