import AppIntents
import Intents
import SFSafeSymbols
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetCustom: Widget {
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
                    states: timelineEntry.entitiesState,
                    showStates: timelineEntry.showStates
                ), type: .custom, showLastUpdate: timelineEntry.showLastUpdateTime, widgetKind: .custom)
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
        Link(destination: AppConstants.createCustomWidgetURL.withWidgetAuthenticity()) {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: .squareBadgePlusFill)
                    .foregroundStyle(Color.haPrimary)
                    .font(.system(size: 55))
                Text(verbatim: L10n.Widgets.Preview.Empty.Create.button)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }

    func modelsForWidget(
        _ widget: CustomWidget?,
        infoProvider: MagicItemProviderProtocol,
        states: [MagicItem: WidgetEntityState],
        showStates: Bool
    ) -> [WidgetBasicViewModel] {
        guard let widget else { return [] }

        return widget.items.map { magicItem in
            let info = infoProvider.getInfo(for: magicItem)
            let state: WidgetEntityState? = states[magicItem]

            var backgroundColor: Color? = nil
            var textColor: Color? = nil

            if let backgroundColorHex = magicItem.customization?.backgroundColor {
                backgroundColor = Color(hex: backgroundColorHex)
            }

            if let textColorHex = magicItem.customization?.textColor {
                textColor = Color(hex: textColorHex)
            }

            let icon: MaterialDesignIcons = {
                if let info {
                    return magicItem.icon(info: info)
                } else {
                    return .gridIcon
                }
            }()

            // The icon takes the color home-assistant/frontend gives the entity — its domain's and
            // device class's `--state-…` palette — unless the user picked one for this tile.
            let iconColor: Color = {
                if !widget.itemsStates.isEmpty {
                    return Color.gray
                }

                let customIconColor = magicItem.customization?.customIconColor.map { Color(hex: $0) }

                // Items the widget never fetches a state for (scripts, scenes, buttons, Assist)
                // have nothing to color from, and keep the app's tint.
                guard showStates, let state else {
                    return customIconColor ?? Color.haPrimary
                }

                return state.iconColor(domain: magicItem.domain, customColor: customIconColor)
            }()

            let title: String = {
                if let info {
                    return magicItem.name(info: info)
                } else {
                    return magicItem.id
                }
            }()

            let useCustomColors = backgroundColor != nil || textColor != nil

            let itemState = widget.itemsStates[magicItem.serverUniqueId]
            let showConfirmation = itemState?.isPendingConfirmation == true

            // The icon is the entity's control and the rest of the tile opens it, the way the
            // frontend's tile card behaves. When both halves would run the same thing there is
            // nothing to split, and the tile stays a single control.
            let iconInteractionType = magicItem.widgetInteractionType
            let tapInteractionType = magicItem.widgetTapInteractionType
            let isSplit = iconInteractionType != tapInteractionType
            let interactionType = isSplit ? tapInteractionType : iconInteractionType
            Current.Log.verbose(
                """
                WidgetCustom: generated item model, widgetId: \(widget.id), itemId: \(magicItem.id), \
                serverId: \(magicItem.serverId), domain: \(String(describing: magicItem.domain?.rawValue)), \
                action: \(String(describing: magicItem.action?.id)), requiresConfirmation: \(
                    magicItem.customization?
                        .requiresConfirmation ?? true
                ), \
                showStates: \(showStates), hasState: \(
                    state !=
                        nil
                ), interactionType: \(String(describing: interactionType))
                """
            )
            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: title,
                subtitle: state?.value,
                area: infoProvider.getAreaName(for: magicItem),
                interactionType: interactionType,
                iconInteractionType: isSplit ? iconInteractionType : nil,
                icon: icon,
                showIconBackground: magicItem.controlsEntityFromWidget,
                textColor: textColor ?? Color(uiColor: .label),
                iconColor: iconColor,
                backgroundColor: backgroundColor ?? Color.tileBackground,
                useCustomColors: useCustomColors,
                showConfirmation: showConfirmation,
                confirmsTapAction: itemState == .pendingTapConfirmation,
                requiresConfirmation: (magicItem.customization?.requiresConfirmation ?? true)
                    || magicItem.requiresConfirmation,
                widgetId: widget.id,
                disabled: !widget.itemsStates.isEmpty
            )
        }
    }
}

enum WidgetCustomSupportedFamilies {
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
    ]
}

#if DEBUG

// UNCOMMENT ON DEMAND: If all previews are uncommented, Xcode will, most probably, fail to render them all at once.

// @available(iOS 17, *)
// #Preview("Small empty", as: .systemSmall) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: []),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

// @available(iOS 17, *)
// #Preview("Small 1 Item", as: .systemSmall) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Small 2 Items", as: .systemSmall) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Small 3 Items", as: .systemSmall) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//            .init(id: "3", serverId: "3", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [.init(id: "3", serverId: "3", type: .entity): .init(value: "On", domainState: .on)],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

// @available(iOS 17, *)
// #Preview("Medium 1 item", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Medium 2 items", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [.init(id: "2", serverId: "2", type: .entity): .init(value: "On", domainState: .on)],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

// @available(iOS 17, *)
// #Preview("Medium 3 items", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//            .init(id: "3", serverId: "3", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [.init(id: "2", serverId: "2", type: .entity): .init(value: "On", domainState: .on)],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

// @available(iOS 17, *)
// #Preview("Medium 4 items", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//            .init(id: "3", serverId: "3", type: .entity),
//            .init(id: "4", serverId: "4", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

// @available(iOS 17, *)
// #Preview("Medium 5 items", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//            .init(id: "3", serverId: "3", type: .entity),
//            .init(id: "4", serverId: "4", type: .entity),
//            .init(id: "5", serverId: "5", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Medium 6 items", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: .init(id: "123", name: "My widget", items: [
//            .init(id: "light.one", serverId: "1", type: .entity, action: .navigate("/lovelace/0")),
//            .init(id: "2", serverId: "2", type: .entity),
//            .init(id: "3", serverId: "3", type: .entity),
//            .init(id: "4", serverId: "4", type: .entity),
//            .init(id: "5", serverId: "5", type: .entity),
//            .init(id: "6", serverId: "6", type: .entity),
//        ]),
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Medium empty", as: .systemMedium) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: nil,
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }
//
// @available(iOS 17, *)
// #Preview("Large empty", as: .systemLarge) {
//    WidgetCustom()
// } timeline: {
//    WidgetCustomEntry(
//        date: .now,
//        widget: nil,
//        magicItemInfoProvider: MockMagicItemProvider(),
//        entitiesState: [:],
//        showLastUpdateTime: true,
//        showStates: true
//    )
// }

final class MockMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [Shared.HAAppEntity]]) -> Void) {
        /* no-op */
    }

    func loadInformation() async -> [String: [Shared.HAAppEntity]] {
        [:]
    }

    func getInfo(for item: Shared.MagicItem) -> Shared.MagicItem.Info? {
        if item.id == "light.one" {
            return .init(id: "1", name: "Abc", iconName: "script", customization: nil)
        } else {
            return .init(id: "2", name: "Cba", iconName: "heart", customization: .init(iconColor: "#FFFFFF"))
        }
    }

    func getAreaName(for item: Shared.MagicItem) -> String? {
        nil
    }
}
#endif
