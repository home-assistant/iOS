import AppIntents
import Intents
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
                    serverName: timelineEntry.serverName
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

    private func modelsForWidget(
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

            let iconColor: Color = {
                let domainsWithActiveState: [Domain] = [.light, .switch, .inputBoolean, .cover, .fan, .climate]
                if showStates, let domain = magicItem.domain, domainsWithActiveState.contains(domain) {
                    if state?.domainState?.isActive ?? false {
                        return state?.color ?? Color.haPrimary
                    } else {
                        return Color.gray
                    }
                } else {
                    return Color.haPrimary
                }
            }()

            let title: String = {
                if let info {
                    return magicItem.name(info: info)
                } else {
                    return magicItem.id
                }
            }()

            let interactionType = magicItem.widgetInteractionType
            let areaName = infoProvider.getAreaName(for: magicItem)
            let subtitle: String? = {
                if let areaName, let state = state?.value {
                    return state + " · " + areaName
                } else {
                    return state?.value
                }
            }()
            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: title,
                subtitle: subtitle,
                interactionType: interactionType,
                icon: icon,
                showIconBackground: true,
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
    @available(iOS 16.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
    ]
}
