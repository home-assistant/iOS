import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenLightItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenLightValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenLightConfiguration) async throws -> ControlOpenLightItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenLightConfiguration) -> ControlOpenLightItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenLightConfiguration) -> ControlOpenLightItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenLightConfiguration) -> ControlOpenLightItem {
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

    private func placeholder() -> ControlOpenLightItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.lightbulb.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenLightConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_light.configuration.title",
        defaultValue: "Open Light"
    )

    @Parameter(
        title: .init("widgets.controls.open_light.configuration.parameter.entity", defaultValue: "Light"),
        optionsProvider: LightEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct LightEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.light]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.lightbulb.rawValue
                    )
                }
            )
        })
    }
}
