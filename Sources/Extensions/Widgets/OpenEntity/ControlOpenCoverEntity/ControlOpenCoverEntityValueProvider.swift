import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenCoverEntityItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenCoverEntityValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenCoverEntityConfiguration) async throws -> ControlOpenCoverEntityItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenCoverEntityConfiguration) -> ControlOpenCoverEntityItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenCoverEntityConfiguration) -> ControlOpenCoverEntityItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenCoverEntityConfiguration) -> ControlOpenCoverEntityItem {
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

    private func placeholder() -> ControlOpenCoverEntityItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.squareOnSquare.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenCoverEntityConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_cover.configuration.title",
        defaultValue: "Open Cover"
    )

    @Parameter(
        title: .init("widgets.controls.open_cover.configuration.parameter.entity", defaultValue: "Cover"),
        optionsProvider: CoverEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct CoverEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.cover]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.squareOnSquare.rawValue
                    )
                }
            )
        })
    }
}
