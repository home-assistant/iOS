import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenButtonItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenButtonValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenButtonConfiguration) async throws -> ControlOpenButtonItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenButtonConfiguration) -> ControlOpenButtonItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenButtonConfiguration) -> ControlOpenButtonItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenButtonConfiguration) -> ControlOpenButtonItem {
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

    private func placeholder() -> ControlOpenButtonItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.circleCircle.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenButtonConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_button.configuration.title",
        defaultValue: "Open Button"
    )

    @Parameter(
        title: .init("widgets.controls.open_button.configuration.parameter.entity", defaultValue: "Button"),
        optionsProvider: ButtonEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct ButtonEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.button]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.circleCircle.rawValue
                    )
                }
            )
        })
    }
}
