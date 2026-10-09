import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlCoverValueProvider: AppIntentControlValueProvider {
    func currentValue(
        configuration: ControlCoverConfiguration
    ) async throws -> ControlCoverValue {
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

        return ControlCoverValue(
            entity: item(
                entity: configuration.entity,
                value: isOpen,
                iconName: icon,
                displayText: configuration.displayText
            ),
            showNextAction: configuration.showNextAction
        )
    }

    func placeholder(
        for configuration: ControlCoverConfiguration
    ) -> ControlCoverValue {
        ControlCoverValue(
            entity: item(
                entity: configuration.entity,
                value: nil,
                iconName: configuration.openIcon,
                displayText: configuration.displayText
            ),
            showNextAction: configuration.showNextAction
        )
    }

    func previewValue(
        configuration: ControlCoverConfiguration
    ) -> ControlCoverValue {
        placeholder(for: configuration)
    }

    private func item(
        entity: IntentCoverEntity?,
        value: Bool?,
        iconName: SFSymbolEntity?,
        displayText: String?
    ) -> ControlEntityItem {
        let placeholder = placeholder(value: value)
        if let entity {
            return .init(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                name: displayText ?? entity.displayString,
                icon: iconName ?? .init(id: placeholder.iconName),
                value: value ?? false
            )
        } else {
            return .init(
                id: placeholder.id,
                entityId: placeholder.entityId,
                serverId: placeholder.serverId,
                name: displayText ?? placeholder.displayString,
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
            displayString: L10n.Widgets.Controls.Cover.pendingConfiguration,
            iconName: (value ?? false) ? SFSymbol.blindsVerticalOpen.rawValue : SFSymbol.blindsVerticalClosed.rawValue
        )
    }
}
