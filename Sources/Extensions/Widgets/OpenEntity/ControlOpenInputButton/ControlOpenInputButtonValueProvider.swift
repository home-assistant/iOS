import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenInputButtonItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenInputButtonValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenInputButtonConfiguration) async throws -> ControlOpenInputButtonItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenInputButtonConfiguration) -> ControlOpenInputButtonItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenInputButtonConfiguration) -> ControlOpenInputButtonItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenInputButtonConfiguration) -> ControlOpenInputButtonItem {
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

    private func placeholder() -> ControlOpenInputButtonItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.circleCircle.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenInputButtonConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_inputButton.configuration.title",
        defaultValue: "Open InputButton"
    )

    @Parameter(
        title: .init("widgets.controls.open_inputButton.configuration.parameter.entity", defaultValue: "InputButton"),
        optionsProvider: InputButtonEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct InputButtonEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.inputButton]).getEntities()

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
