import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenBinarySensorItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenBinarySensorValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenBinarySensorConfiguration) async throws -> ControlOpenBinarySensorItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenBinarySensorConfiguration) -> ControlOpenBinarySensorItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenBinarySensorConfiguration) -> ControlOpenBinarySensorItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenBinarySensorConfiguration) -> ControlOpenBinarySensorItem {
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

    private func placeholder() -> ControlOpenBinarySensorItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.eyeOutline.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenBinarySensorConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_binarySensor.configuration.title",
        defaultValue: "Open BinarySensor"
    )

    @Parameter(
        title: .init("widgets.controls.open_binarySensor.configuration.parameter.entity", defaultValue: "BinarySensor"),
        optionsProvider: BinarySensorEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct BinarySensorEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.binarySensor]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.eyeOutline.rawValue
                    )
                }
            )
        })
    }
}
