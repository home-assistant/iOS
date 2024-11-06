import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlCoverValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlCoverConfiguration) async throws -> ControlEntityItem {
        /*
         For now we don't have a reliable way to get the current state of a cover
         due to the fact that we don't know when the cover will finish opening or closing
         and we can't always update through push notification due to user push notification limitations
         */
        let isOpen = false

        return item(entity: configuration.entity, value: isOpen, iconName: configuration.icon)
    }

    func placeholder(for configuration: ControlCoverConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.icon)
    }

    func previewValue(configuration: ControlCoverConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.icon)
    }

    private func item(entity: IntentCoverEntity?, value: Bool?, iconName: SFSymbolEntity?) -> ControlEntityItem {
        let placeholder = placeholder(value: value)
        if let entity {
            return .init(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                name: entity.displayString,
                icon: iconName ?? .init(id: placeholder.iconName),
                value: value ?? false
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

    private func placeholder(value: Bool?) -> IntentCoverEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            displayString: L10n.Widgets.Controls.Cover.placeholderTitle,
            iconName: (value ?? false) ? SFSymbol.blindsVerticalOpen.rawValue : SFSymbol.blindsVerticalClosed.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlCoverConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.cover.description",
        defaultValue: "Toggle cover"
    )

    @Parameter(
        title: .init("widgets.controls.cover.title", defaultValue: "Cover")
    )
    var entity: IntentCoverEntity?
    @Parameter(
        title: .init("app_intents.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
