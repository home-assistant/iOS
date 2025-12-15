import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenSceneItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenSceneValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenSceneConfiguration) async throws -> ControlOpenSceneItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenSceneConfiguration) -> ControlOpenSceneItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenSceneConfiguration) -> ControlOpenSceneItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenSceneConfiguration) -> ControlOpenSceneItem {
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

    private func placeholder() -> ControlOpenSceneItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.paintbrush.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenSceneConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_scene.configuration.title",
        defaultValue: "Open Scene"
    )

    @Parameter(
        title: .init("widgets.controls.open_scene.configuration.parameter.entity", defaultValue: "Scene"),
        optionsProvider: SceneEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct SceneEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.scene]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.paintbrush.rawValue
                    )
                }
            )
        })
    }
}
