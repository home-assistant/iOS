import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlCoverValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlCoverConfiguration) async throws -> ControlEntityItem {
        guard let serverId = configuration.entity?.serverId,
              let CoverId = configuration.entity?.entityId,
              let state = try await ControlEntityProvider(domain: .cover).currentState(
                  serverId: serverId,
                  entityId: CoverId
              ) else {
            throw AppIntentError.restartPerform
        }

        let isOpen = state == ControlEntityProvider.States.open.rawValue

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
            displayString: L10n.Widgets.Controls.Scripts.placeholderTitle,
            iconName: (value ?? false) ? SFSymbol.blindsVerticalOpen.rawValue : SFSymbol.blindsVerticalClosed.rawValue
        )
    }
}

@available(iOS 18.0, *)
struct ControlCoverConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.Cover.description",
        defaultValue: "Turn on/off Cover"
    )

    @Parameter(
        title: .init("widgets.controls.Cover.title", defaultValue: "Cover")
    )
    var entity: IntentCoverEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
