import HAKit
import Shared
import SwiftUI

extension HomeEntityPresenter {
    /// The presenter the app uses: the icons, colours and wording the rest of the app already draws
    /// entities with, so a tile on the native home reads exactly like the same entity on a widget,
    /// in CarPlay or on the watch.
    ///
    /// - Parameters:
    ///   - entities: the live states, by entity id. The dashboard's own registry carries a cut-down
    ///     copy; naming and colouring a state needs the whole thing.
    ///   - iconsMap: the server's `entity_component` icon map, when it has been fetched.
    ///   - serverId: used to format numeric states with the precision the registry holds.
    static func app(
        entities: [String: HAEntity],
        iconsMap: EntityComponentIconsMap?,
        serverId: String
    ) -> HomeEntityPresenter {
        HomeEntityPresenter { state, _ in
            guard let entity = entities[state.id] else {
                return HomeEntityPresentation(
                    icon: HomeDashboardIconName.icon(state.attributes.icon),
                    color: .haDisabled,
                    primary: HomeEntityNameFormatter.name(of: state),
                    isUnavailable: true
                )
            }
            let domain = Domain(rawValue: entity.domain)
            return HomeEntityPresentation(
                icon: entity.getMDI(componentIcons: iconsMap),
                color: Color(uiColor: entity.stateIconColor() ?? .label),
                primary: entity.attributes.friendlyName ?? HomeEntityNameFormatter.name(of: state),
                secondary: domain?.contextualStateDescription(for: entity, serverId: serverId)
                    ?? entity.state.leadingCapitalized,
                isActive: EntityStateActive.isActive(domain: domain, state: entity.state),
                isUnavailable: state.isUnavailable
            )
        }
    }
}
