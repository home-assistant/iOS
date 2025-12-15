import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenZoneItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenZoneValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenZoneConfiguration) async throws -> ControlOpenZoneItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenZoneConfiguration) -> ControlOpenZoneItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenZoneConfiguration) -> ControlOpenZoneItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenZoneConfiguration) -> ControlOpenZoneItem {
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

    private func placeholder() -> ControlOpenZoneItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.mapMarker.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenZoneConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_zone.configuration.title",
        defaultValue: "Open Zone"
    )

    @Parameter(
        title: .init("widgets.controls.open_zone.configuration.parameter.entity", defaultValue: "Zone"),
        optionsProvider: ZoneEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct ZoneEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.zone]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.mapMarker.rawValue
                    )
                }
            )
        })
    }
}
