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
                ), type: .custom, showLastUpdate: timelineEntry.showLastUpdateTime)
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
        let url = URL(string: "\(AppConstants.deeplinkURL.absoluteString)createCustomWidget")!
        return Link(destination: url.withWidgetAuthenticity()) {
            VStack(spacing: Spaces.two) {
                Image(systemSymbol: .squareBadgePlusFill)
                    .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
                    .font(.system(size: 55))
                Text(L10n.Widgets.Preview.Empty.Create.button)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }

    private func modelsForWidget(
        _ widget: CustomWidget?,
        infoProvider: MagicItemProviderProtocol,
        states: [MagicItem: WidgetCustomEntry.ItemState],
        showStates: Bool
    ) -> [WidgetBasicViewModel] {
        guard let widget else { return [] }

        return widget.items.map { magicItem in
            let info = infoProvider.getInfo(for: magicItem)
            let state: WidgetCustomEntry.ItemState? = states[magicItem]

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

            let iconColor: Color = {
                let magicItemIconColor = {
                    if let iconColor = magicItem.customization?.iconColor {
                        return Color(hex: iconColor)
                    } else {
                        return Color.asset(Asset.Colors.haPrimary)
                    }
                }()

                if !widget.itemsStates.isEmpty {
                    return Color.gray
                } else if showStates, [.light, .switch, .inputBoolean].contains(magicItem.domain) {
                    if state?.domainState == Domain.State.off {
                        return Color.gray
                    } else {
                        return magicItemIconColor
                    }
                } else {
                    return magicItemIconColor
                }
            }()

            let title: String = {
                if let info {
                    return magicItem.name(info: info)
                } else {
                    return magicItem.id
                }
            }()

            let useCustomColors = backgroundColor != nil || textColor != nil

            let showConfirmation = {
                if let itemState = widget.itemsStates.first(where: { $0.key == magicItem.serverUniqueId })?.value {
                    return itemState == .pendingConfirmation
                } else {
                    return false
                }
            }()

            return WidgetBasicViewModel(
                id: magicItem.serverUniqueId,
                title: title,
                subtitle: state?.value,
                interactionType: interactionTypeForItem(magicItem),
                icon: icon,
                textColor: textColor ?? Color(uiColor: .label),
                iconColor: iconColor,
                backgroundColor: backgroundColor ?? Color.asset(Asset.Colors.tileBackground),
                useCustomColors: useCustomColors,
                showConfirmation: showConfirmation,
                requiresConfirmation: magicItem.customization?.requiresConfirmation ?? true,
                widgetId: widget.id,
                disabled: !widget.itemsStates.isEmpty
            )
        }
    }

    private func interactionTypeForItem(_ magicItem: MagicItem) -> WidgetBasicViewModel.InteractionType {
        guard let domain = magicItem.domain else { return .appIntent(.refresh) }

        var interactionType: WidgetBasicViewModel.InteractionType = .appIntent(.refresh)

        if let magicItemAction = magicItem.action, magicItemAction != .default {
            switch magicItemAction {
            case .default:
                // This block of code should not be reached, default should not be handled here
                // Returning something to avoid compiler error
                interactionType = .appIntent(.refresh)
            case .nothing:
                interactionType = .appIntent(.refresh)
            case let .navigate(path):
                interactionType = navigateIntent(magicItem, path: path)
            case let .runScript(serverId, scriptId):
                interactionType = .appIntent(.activate(
                    entityId: scriptId,
                    domain: Domain.script.rawValue,
                    serverId: serverId
                ))
            case let .assist(serverId, pipelineId, startListening):
                interactionType = assistIntent(
                    serverId: serverId,
                    pipelineId: pipelineId,
                    startListening: startListening
                )
            }
        } else {
            switch domain {
            case .button, .inputButton:
                interactionType = .appIntent(.press(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            case .cover, .inputBoolean, .light, .switch:
                interactionType = .appIntent(.toggle(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            case .lock:
                // TODO: Support lock action in widgets
                interactionType = .appIntent(.refresh)
            case .scene, .script:
                interactionType = .appIntent(.activate(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            default:
                interactionType = .appIntent(.refresh)
            }
        }

        return interactionType
    }

    private func navigateIntent(_ magicItem: MagicItem, path: String) -> WidgetBasicViewModel.InteractionType {
        var path = path
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        if let url =
            URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)navigate/\(path)?server=\(magicItem.serverId)"
            ) {
            return .widgetURL(url)
        } else {
            return .appIntent(.refresh)
        }
    }

    private func assistIntent(serverId: String, pipelineId: String, startListening: Bool) -> WidgetBasicViewModel
        .InteractionType {
        if let url =
            URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)assist?serverId=\(serverId)&pipelineId=\(pipelineId)&startListening=\(startListening)"
            ) {
            return .widgetURL(url)
        } else {
            return .appIntent(.refresh)
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
    WidgetCustomEntry(
        date: .now,
        widget: .init(id: "123", name: "My widget", items: [
            .init(id: "1", serverId: "1", type: .entity),
            .init(id: "2", serverId: "2", type: .entity),
        ]),
        magicItemInfoProvider: MockMagicItemProvider(),
        entitiesState: [:],
        showLastUpdateTime: true,
        showStates: true
    )
}

@available(iOS 17, *)
#Preview(as: .systemMedium) {
    WidgetCustom()
} timeline: {
    WidgetCustomEntry(
        date: .now,
        widget: nil,
        magicItemInfoProvider: MockMagicItemProvider(),
        entitiesState: [:],
        showLastUpdateTime: true,
        showStates: true
    )
}

@available(iOS 17, *)
#Preview(as: .systemLarge) {
    WidgetCustom()
} timeline: {
    WidgetCustomEntry(
        date: .now,
        widget: nil,
        magicItemInfoProvider: MockMagicItemProvider(),
        entitiesState: [:],
        showLastUpdateTime: true,
        showStates: true
    )
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
