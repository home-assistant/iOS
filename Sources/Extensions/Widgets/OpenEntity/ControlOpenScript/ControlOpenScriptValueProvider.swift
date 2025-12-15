import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenScriptItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenScriptValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenScriptConfiguration) async throws -> ControlOpenScriptItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenScriptConfiguration) -> ControlOpenScriptItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenScriptConfiguration) -> ControlOpenScriptItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenScriptConfiguration) -> ControlOpenScriptItem {
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

    private func placeholder() -> ControlOpenScriptItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.scriptTextOutline.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenScriptConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_script.configuration.title",
        defaultValue: "Open Script"
    )

    @Parameter(
        title: .init("widgets.controls.open_script.configuration.parameter.entity", defaultValue: "Script"),
        optionsProvider: ScriptEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct ScriptEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.script]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.scriptTextOutline.rawValue
                    )
                }
            )
        })
    }
}
