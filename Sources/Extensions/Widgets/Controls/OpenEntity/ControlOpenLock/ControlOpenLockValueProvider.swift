import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenLockItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
    let displayText: String?
}

@available(iOS 18, *)
struct ControlOpenLockValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenLockConfiguration) async throws -> ControlOpenLockItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenLockConfiguration) -> ControlOpenLockItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenLockConfiguration) -> ControlOpenLockItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenLockConfiguration) -> ControlOpenLockItem {
        .init(
            entity: configuration.entity ?? .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: L10n.Widgets.Controls.OpenLock.pendingConfiguration,
                iconName: ""
            ),
            icon: configuration.icon ?? placeholder().icon,
            displayText: configuration.displayText
        )
    }

    private func placeholder() -> ControlOpenLockItem {
        .init(
            entity: .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: L10n.Widgets.Controls.OpenLock.pendingConfiguration,
                iconName: ""
            ),
            icon: .init(id: SFSymbol.lock.rawValue),
            displayText: nil
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenLockConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_lock.configuration.title",
        defaultValue: "Open Lock"
    )

    @Parameter(
        title: .init("widgets.controls.open_lock.configuration.parameter.entity", defaultValue: "Lock"),
        optionsProvider: LockEntityOptionsProvider()
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
struct LockEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.lock]).getEntities()

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
                        iconName: entity.icon ?? SFSymbol.lock.rawValue
                    )
                }
            )
        })
    }
}
