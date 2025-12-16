import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlButtonValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlButtonConfiguration) async throws -> ControlEntityItem {
        item(entity: configuration.entity, iconName: configuration.icon)
    }

    func placeholder(for configuration: ControlButtonConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, iconName: configuration.icon)
    }

    func previewValue(configuration: ControlButtonConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, iconName: configuration.icon)
    }

    private func item(entity: IntentButtonEntity?, iconName: SFSymbolEntity?) -> ControlEntityItem {
        let placeholder = placeholder()
        if let entity {
            return .init(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                name: entity.displayString,
                icon: iconName ?? .init(id: entity.iconName),
                value: false // Buttons are stateless
            )
        } else {
            return .init(
                id: placeholder.id,
                entityId: placeholder.entityId,
                serverId: placeholder.serverId,
                name: placeholder.displayString,
                icon: .init(id: placeholder.iconName),
                value: false
            )
        }
    }

    private func placeholder() -> IntentButtonEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            displayString: L10n.Widgets.Controls.Button.placeholderTitle,
            iconName: SFSymbol.circleCircle.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlButtonConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.button.title",
        defaultValue: "Button"
    )

    @Parameter(
        title: .init("widgets.controls.button.title", defaultValue: "Button")
    )
    var entity: IntentButtonEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
