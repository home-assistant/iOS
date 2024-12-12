import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlCoverValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlCoverConfiguration) async throws -> ControlEntityItem {
        try await ControlRefreshDelay.wait()
        guard let serverId = configuration.entity?.serverId,
              let lightId = configuration.entity?.entityId,
              let state: String = try await ControlEntityProvider(domains: [.cover]).currentState(
                  serverId: serverId,
                  entityId: lightId
              ) else {
            throw AppIntentError.restartPerform
        }
        let isOpen = [
            ControlEntityProvider.States.open.rawValue,
            ControlEntityProvider.States.opening.rawValue,
        ].contains(state)
        let icon = isOpen ? configuration.openIcon : configuration.closedIcon
        return item(entity: configuration.entity, value: isOpen, iconName: icon)
    }

    func placeholder(for configuration: ControlCoverConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.openIcon)
    }

    func previewValue(configuration: ControlCoverConfiguration) -> ControlEntityItem {
        item(entity: configuration.entity, value: nil, iconName: configuration.openIcon)
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
        title: .init("app_intents.open_state_icon.title", defaultValue: "Icon for open state"),
        default: SFSymbolEntity(id: SFSymbol.curtainsOpen.rawValue)
    )
    var openIcon: SFSymbolEntity?
    @Parameter(
        title: .init("app_intents.closed_state_icon.title", defaultValue: "Icon for closed state"),
        default: SFSymbolEntity(id: SFSymbol.curtainsClosed.rawValue)
    )
    var closedIcon: SFSymbolEntity?
}
