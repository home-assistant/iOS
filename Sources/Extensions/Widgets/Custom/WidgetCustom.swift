import AppIntents
import Intents
import SFSafeSymbols
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetCustom: Widget {
    @Environment(\.widgetFamily) private var family

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.custom.rawValue,
            provider: WidgetCustomTimelineProvider()
        ) { timelineEntry in
            if let widget = timelineEntry.widget {
                WidgetBasicContainerView(emptyViewGenerator: {
                    AnyView(emptyView)
                }, contents: modelsForWidget(
                    widget,
                    infoProvider: timelineEntry.magicItemInfoProvider,
                    states: timelineEntry.itemStates
                ), type: .custom)
            } else {
                emptyView
                    .widgetBackground(Color.clear)
            }
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Preview.Custom.title)
        .description(L10n.Widgets.Preview.Custom.description)
        .supportedFamilies(WidgetCustomSupportedFamilies.families)
    }

    private var emptyView: some View {
        // TODO: Wrap into a button and add intent to create widget
        VStack(spacing: Spaces.two) {
            Image(systemSymbol: .squareBadgePlusFill)
                .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
                .font(.system(size: 55))
            Text(L10n.Widgets.Preview.Empty.Create.button)
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    private func modelsForWidget(
        _ widget: CustomWidget?,
        infoProvider: MagicItemProviderProtocol,
        states: [MagicItem: String]
    ) -> [WidgetBasicViewModel] {
        guard let widget else { return [] }

        return widget.items.prefix({
            let maxItemsForFamily = WidgetFamilySizes.size(for: family)
            return maxItemsForFamily
        }()).map { magicItem in
            let info = infoProvider.getInfo(for: magicItem)

            var iconColor: Color? = nil
            var backgroundColor: Color? = nil
            var textColor: Color? = nil

            if let iconColorHex = magicItem.customization?.iconColor {
                iconColor = Color(hex: iconColorHex)
            }

            if let backgroundColorHex = magicItem.customization?.backgroundColor {
                backgroundColor = Color(hex: backgroundColorHex)
            }

            if let textColorHex = magicItem.customization?.textColor {
                textColor = Color(hex: textColorHex)
            }

            let useCustomColors = backgroundColor != nil || textColor != nil
            let state: String? = states[magicItem]?.capitalizedFirst

            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: magicItem.displayText ?? info?.name ?? magicItem.id,
                subtitle: state,
                interactionType: .appIntent(intentForItem(magicItem)),
                icon: MaterialDesignIcons(serversideValueNamed: info?.iconName ?? "", fallback: .dotsGridIcon),
                textColor: textColor ?? Color(uiColor: .label),
                iconColor: iconColor ?? Color.asset(Asset.Colors.haPrimary),
                backgroundColor: backgroundColor ?? Color.asset(Asset.Colors.tileBackground),
                useCustomColors: useCustomColors
            )
        }
    }

    private func intentForItem(_ magicItem: MagicItem) -> WidgetBasicViewModel.WidgetIntentType {
        guard let domain = magicItem.domain else { return .refresh }

        if let magicItemAction = magicItem.action, magicItemAction != .default {
            switch magicItemAction {
            case .default, .nothing:
                return .refresh
            case .toggle:
                return .toggle(entityId: magicItem.id, serverId: magicItem.serverId)
            case let .navigate(path):
                return .navigate(serverId: magicItem.serverId, path: path)
            case let .runScript(serverId, scriptId):
                return .activate(entityId: scriptId, serverId: serverId)
            case let .assist(serverId, pipelineId, startListening):
                return .assist(serverId: serverId, pipelineId: pipelineId, startListening: startListening)
            }
        } else {
            switch domain {
            case .button, .inputButton:
                return .press(entityId: magicItem.id, serverId: magicItem.serverId)
            case .cover, .inputBoolean, .light, .switch:
                return .toggle(entityId: magicItem.id, serverId: magicItem.serverId)
            case .lock:
                // TODO: Support lock action in widgets
                return .refresh
            case .scene, .script:
                return .activate(entityId: magicItem.id, serverId: magicItem.serverId)
            default:
                return .refresh
            }
        }
    }
}

enum WidgetCustomSupportedFamilies {
    @available(iOS 16.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
    ]
}

#if DEBUG
@available(iOS 17, *)
#Preview(as: .systemSmall) {
    WidgetCustom()
} timeline: {
    WidgetCustomEntry(date: .now, widget: .init(name: "My widget", items: [
        .init(id: "1", serverId: "1", type: .entity),
        .init(id: "2", serverId: "2", type: .entity),
    ]), magicItemInfoProvider: MockMagicItemProvider(), itemStates: [:])
}

@available(iOS 17, *)
#Preview(as: .systemMedium) {
    WidgetCustom()
} timeline: {
    WidgetCustomEntry(date: .now, widget: nil, magicItemInfoProvider: MockMagicItemProvider(), itemStates: [:])
}

@available(iOS 17, *)
#Preview(as: .systemLarge) {
    WidgetCustom()
} timeline: {
    WidgetCustomEntry(date: .now, widget: nil, magicItemInfoProvider: MockMagicItemProvider(), itemStates: [:])
}

final class MockMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [Shared.HAAppEntity]]) -> Void) {
        /* no-op */
    }

    func loadInformation() async -> [String: [Shared.HAAppEntity]] {
        [:]
    }

    func getInfo(for item: Shared.MagicItem) -> Shared.MagicItem.Info? {
        if item.id == "1" {
            return .init(id: "1", name: "Abc", iconName: "script", customization: nil)
        } else {
            return .init(id: "2", name: "Cba", iconName: "heart", customization: .init(iconColor: "#FFFFFF"))
        }
    }
}
#endif
