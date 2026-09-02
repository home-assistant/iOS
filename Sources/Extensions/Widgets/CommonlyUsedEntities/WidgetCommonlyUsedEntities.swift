import AppIntents
import SFSafeSymbols
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetCommonlyUsedEntities: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.commonlyUsedEntities.rawValue,
            provider: WidgetCommonlyUsedEntitiesTimelineProvider()
        ) { timelineEntry in
            if !timelineEntry.items.isEmpty {
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(emptyView)
                    },
                    contents: modelsForWidget(
                        items: timelineEntry.items,
                        infoProvider: timelineEntry.magicItemInfoProvider,
                        states: timelineEntry.entitiesState,
                        showStates: timelineEntry.showStates
                    ),
                    type: .custom,
                    showLastUpdate: timelineEntry.showLastUpdateTime,
                    showServerName: timelineEntry.serverName != nil,
                    serverName: timelineEntry.serverName,
                    widgetKind: .commonlyUsedEntities
                )
            } else {
                emptyView
                    .widgetBackground(Color.clear)
            }
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.CommonlyUsedEntities.title)
        .description(L10n.Widgets.CommonlyUsedEntities.description)
        .supportedFamilies(WidgetCommonlyUsedEntitiesSupportedFamilies.families)
    }

    private var emptyView: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .clockArrowCirclepath)
                .foregroundStyle(Color.haPrimary)
                .font(.system(size: 55))
            Text(verbatim: L10n.Widgets.CommonlyUsedEntities.Empty.description)
                .foregroundStyle(.secondary)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }

    func modelsForWidget(
        items: [MagicItem],
        infoProvider: MagicItemProviderProtocol,
        states: [MagicItem: WidgetEntityState],
        showStates: Bool
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
            // device class's `--state-…` palette. Items the widget fetches no state for keep the
            // app's tint.
            let iconColor: Color = {
                guard showStates, let state else { return Color.haPrimary }
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
            // Area above the name and state below it, the way the Home app stacks a tile: one
            // line each, so a long area no longer pushes the state off the end of a shared line.
            let areaName = infoProvider.getAreaName(for: magicItem)
            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: title,
                subtitle: state?.value,
                area: areaName,
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

enum WidgetCommonlyUsedEntitiesSupportedFamilies {
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
    ]
}
