import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenSensorItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenSensorValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenSensorConfiguration) async throws -> ControlOpenSensorItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenSensorConfiguration) -> ControlOpenSensorItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenSensorConfiguration) -> ControlOpenSensorItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenSensorConfiguration) -> ControlOpenSensorItem {
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

    private func placeholder() -> ControlOpenSensorItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.eye.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenSensorConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_sensor.configuration.title",
        defaultValue: "Open Sensor"
    )

    @Parameter(
        title: .init("widgets.controls.open_sensor.configuration.parameter.entity", defaultValue: "Sensor"),
        optionsProvider: SensorEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct SensorEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.sensor, .binarySensor]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.eye.rawValue
                    )
                }
            )
        })
    }
}
