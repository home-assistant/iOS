import SFSafeSymbols
import Shared
import UIKit

enum AppIconShortcutItemsUpdater {
    private static let shortcutTypePrefix = "appIconShortcut."
    private static let shortcutTypeSeparator: Character = "|"
    private static let maximumShortcutItems = 4

    struct ShortcutIdentifier: Equatable {
        let serverId: String
        let itemId: String
        let itemType: MagicItem.ItemType
    }

    static func update() {
        let forcedShortcutItems = Self.forcedShortcutItems
        if forcedShortcutItems.isEmpty == false {
            publish(shortcutItems: forcedShortcutItems)
        }

        // `loadInformation` fetches every entity, area, and device row for every server
        // synchronously on the calling thread, and `update()` runs at app launch — keep that work
        // off the main thread. The resulting items are published back on main.
        DispatchQueue.global(qos: .utility).async {
            let magicItemProvider = Current.magicItemProvider()
            magicItemProvider.loadInformation { _ in
                let config = (try? AppIconShortcutConfig.config()) ?? AppIconShortcutConfig()
                let configuredShortcutItems = config.items
                    .filter { $0.type != .unsupported }
                    .prefix(maximumShortcutItems)
                    .map { item in
                        UIApplicationShortcutItem(
                            type: shortcutType(for: item),
                            localizedTitle: title(for: item, provider: magicItemProvider),
                            localizedSubtitle: subtitle(for: item, provider: magicItemProvider),
                            icon: icon(for: item, provider: magicItemProvider)
                        )
                    }
                let shortcutItems = forcedShortcutItems + configuredShortcutItems
                publish(shortcutItems: shortcutItems)
            }
        }
    }

    static func identifier(from shortcutType: String) -> ShortcutIdentifier? {
        guard shortcutType.hasPrefix(shortcutTypePrefix) else { return nil }
        let payload = shortcutType.dropFirst(shortcutTypePrefix.count)
        let parts = payload.split(separator: shortcutTypeSeparator, maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              let itemType = MagicItem.ItemType(rawValue: String(parts[1])) else {
            return nil
        }
        return ShortcutIdentifier(
            serverId: String(parts[0]),
            itemId: String(parts[2]),
            itemType: itemType
        )
    }

    private static func shortcutType(for item: MagicItem) -> String {
        let separator = shortcutTypeSeparator
        return "\(shortcutTypePrefix)\(item.serverId)\(separator)\(item.type.rawValue)\(separator)\(item.id)"
    }

    private static var forcedShortcutItems: [UIApplicationShortcutItem] {
        guard Current.isCatalyst else { return [] }
        return [
            .init(
                type: HAApplicationShortcutItem.openSettings.rawValue,
                localizedTitle: L10n.ShortcutItem.OpenSettings.title,
                localizedSubtitle: nil,
                icon: .init(systemSymbol: .gear)
            ),
        ]
    }

    private static func publish(shortcutItems: [UIApplicationShortcutItem]) {
        DispatchQueue.main.async {
            UIApplication.shared.shortcutItems = shortcutItems
        }
    }

    private static func title(for item: MagicItem, provider: MagicItemProviderProtocol) -> String {
        if let info = provider.getInfo(for: item) {
            return item.name(info: info)
        } else {
            return item.displayText ?? item.id
        }
    }

    private static func subtitle(for item: MagicItem, provider: MagicItemProviderProtocol) -> String? {
        provider.getAreaName(for: item)
    }

    static func materialDesignIcon(
        for item: MagicItem,
        provider: MagicItemProviderProtocol
    ) -> MaterialDesignIcons {
        if let info = provider.getInfo(for: item) {
            return item.icon(info: info)
        }
        return fallbackIcon(for: item.type)
    }

    static func fallbackIcon(for type: MagicItem.ItemType) -> MaterialDesignIcons {
        switch type {
        case .script: return .scriptIcon
        case .scene: return .paletteIcon
        case .entity: return .dotsGridIcon
        case .folder: return .folderIcon
        case .area: return .textureBoxIcon
        case .assistPipeline: return .microphoneIcon
        case .assistPrompt: return .messageProcessingOutlineIcon
        case .complication: return .watchIcon
        case .unsupported: return .dotsGridIcon
        }
    }

    private static func icon(for item: MagicItem, provider: MagicItemProviderProtocol) -> UIApplicationShortcutIcon? {
        guard item.type != .unsupported else { return nil }
        // Home-screen shortcut icons only accept SF Symbols / bundled templates. Map the item's
        // MaterialDesignIcons glyph (enum names end with `Icon`) through `similarSFSymbol` rather
        // than passing MDI names as string SF Symbols, which do not resolve and appear blank.
        return .init(systemSymbol: materialDesignIcon(for: item, provider: provider).similarSFSymbol)
    }
}
