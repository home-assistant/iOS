import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenPersonItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenPersonValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenPersonConfiguration) async throws -> ControlOpenPersonItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenPersonConfiguration) -> ControlOpenPersonItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenPersonConfiguration) -> ControlOpenPersonItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenPersonConfiguration) -> ControlOpenPersonItem {
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

    private func placeholder() -> ControlOpenPersonItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.personFill.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenPersonConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_person.configuration.title",
        defaultValue: "Open Person"
    )

    @Parameter(
        title: .init("widgets.controls.open_person.configuration.parameter.entity", defaultValue: "Person"),
        optionsProvider: PersonEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct PersonEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.person]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.personFill.rawValue
                    )
                }
            )
        })
    }
}
