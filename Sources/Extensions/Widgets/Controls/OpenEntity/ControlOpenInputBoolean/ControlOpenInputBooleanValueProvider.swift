import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenInputBooleanItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
    let displayText: String?
}

@available(iOS 18, *)
struct ControlOpenInputBooleanValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenInputBooleanConfiguration) async throws -> ControlOpenInputBooleanItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenInputBooleanConfiguration) -> ControlOpenInputBooleanItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenInputBooleanConfiguration) -> ControlOpenInputBooleanItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenInputBooleanConfiguration) -> ControlOpenInputBooleanItem {
        .init(
            entity: configuration.entity ?? .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: L10n.Widgets.Controls.OpenInputBoolean.pendingConfiguration,
                iconName: ""
            ),
            icon: configuration.icon ?? placeholder().icon,
            displayText: configuration.displayText
        )
    }

    private func placeholder() -> ControlOpenInputBooleanItem {
        .init(
            entity: .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: L10n.Widgets.Controls.OpenInputBoolean.pendingConfiguration,
                iconName: ""
            ),
            icon: .init(id: SFSymbol.switchProgrammableFill.rawValue),
            displayText: nil
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenInputBooleanConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_input_boolean.configuration.title",
        defaultValue: "Open InputBoolean"
    )

    @Parameter(
        title: .init(
            "widgets.controls.open_input_boolean.configuration.parameter.entity",
            defaultValue: "InputBoolean"
        ),
        optionsProvider: InputBooleanEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
    @Parameter(
        title: .init("app_intents.display_text.title", defaultValue: "Display Text")
    )
    var displayText: String?
}

@available(iOS 18.0, *)
struct InputBooleanEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.inputBoolean]).getEntities()

        return .init(sections: entities.map { (key: Server, value: [HAAppEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.map { entity in
                    HAAppEntityAppIntentEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        serverName: key.info.name,
                        displayString: entity.name,
                        iconName: entity.icon ?? SFSymbol.switchProgrammable.rawValue
                    )
                }
            )
        })
    }
}
