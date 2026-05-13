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

        let magicItemProvider = Current.magicItemProvider()
        magicItemProvider.loadInformation { _ in
            let config = (try? AppIconShortcutConfig.config()) ?? AppIconShortcutConfig()
            let configuredShortcutItems = config.items.prefix(maximumShortcutItems).map { item in
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

    private static func icon(for item: MagicItem, provider: MagicItemProviderProtocol) -> UIApplicationShortcutIcon? {
        switch item.type {
        case .action:
            return .init(systemSymbol: .boltFill)
        case .script:
            return .init(systemSymbol: .applescriptFill)
        case .scene:
            return .init(systemSymbol: .sparkles)
        case .entity:
            return .init(systemSymbol: .rectangleAndPaperclip)
        case .folder:
            return .init(systemSymbol: .folderFill)
        case .assistPipeline:
            return .init(systemSymbol: .micFill)
        }
    }
}
