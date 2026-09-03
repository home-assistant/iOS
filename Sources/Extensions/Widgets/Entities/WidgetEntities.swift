import AppIntents
import Shared
import SwiftUI
import WidgetKit

/// A grid of entity tiles the user picks one by one: a server, then as many of its entities as
/// the family holds.
///
/// Each tile behaves like the frontend's tile card. The icon runs the entity's main action when
/// the widget can perform it in place (toggle a light, press a button, activate a scene), and the
/// rest of the tile opens the entity in the app. Entities with no single main action — sensors,
/// locks, media players — open in the app from both halves. States are always shown; the only
/// display option the configuration offers is the last update time.
@available(iOS 17, *)
struct WidgetEntities: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.entities.rawValue,
            provider: WidgetEntitiesTimelineProvider()
        ) { timelineEntry in
            WidgetBasicContainerView(
                emptyViewGenerator: {
                    AnyView(WidgetEmptyStateView(message: L10n.Widgets.Entities.notConfigured))
                },
                contents: modelsForWidget(
                    items: timelineEntry.items,
                    infoProvider: timelineEntry.magicItemInfoProvider,
                    states: timelineEntry.entitiesState
                ),
                type: .custom,
                showLastUpdate: timelineEntry.showLastUpdateTime,
                showServerName: timelineEntry.serverName != nil,
                serverName: timelineEntry.serverName,
                widgetKind: .entities
            )
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Entities.title)
        .description(L10n.Widgets.Entities.description)
        .supportedFamilies(WidgetEntitiesSupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetEntitiesSupportedFamilies.families)
    }

    /// States are not optional for this widget, so every tile that has a state shows it and takes
    /// the icon color the frontend gives that state.
    func modelsForWidget(
        items: [MagicItem],
        infoProvider: MagicItemProviderProtocol,
        states: [MagicItem: WidgetEntityState]
    ) -> [WidgetBasicViewModel] {
        items.map { magicItem in
            let info = infoProvider.getInfo(for: magicItem)
            let state: WidgetEntityState? = states[magicItem]

            let icon: MaterialDesignIcons = {
                if let info {
                    return magicItem.icon(info: info)
                } else {
                    return .gridIcon
                }
            }()

            // The icon takes the color home-assistant/frontend gives the entity — its domain's and
            // device class's `--state-…` palette. A tile whose state has not arrived yet keeps the
            // app's tint.
            let iconColor: Color = {
                guard let state else { return Color.haPrimary }
                return state.iconColor(domain: magicItem.domain)
            }()

            let title: String = {
                if let info {
                    return magicItem.name(info: info)
                } else {
                    return magicItem.id
                }
            }()

            // The icon controls the entity and the rest of the tile opens it, the way the
            // frontend's tile card behaves. An entity the widget can't act on has both halves
            // opening it, so there is nothing to split and the tile stays a single control.
            let iconInteractionType = magicItem.widgetInteractionType
            let tapInteractionType = magicItem.widgetTapInteractionType
            let isSplit = iconInteractionType != tapInteractionType
            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: title,
                subtitle: state?.value,
                area: infoProvider.getAreaName(for: magicItem),
                interactionType: isSplit ? tapInteractionType : iconInteractionType,
                iconInteractionType: isSplit ? iconInteractionType : nil,
                icon: icon,
                showIconBackground: magicItem.controlsEntityFromWidget,
                textColor: Color(uiColor: .label),
                iconColor: iconColor,
                backgroundColor: Color.tileBackground,
                useCustomColors: false,
                showConfirmation: false,
                requiresConfirmation: false
            )
        }
    }
}

enum WidgetEntitiesSupportedFamilies {
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
    ]
}
