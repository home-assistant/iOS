import SFSafeSymbols
import Shared
import UIKit

enum AppIconShortcutItemsUpdater {
    private static let shortcutTypePrefix = "appIconShortcut."
    private static let maximumShortcutItems = 4

    static func update() {
        if Current.isCatalyst {
            UIApplication.shared.shortcutItems = [.init(
                type: HAApplicationShortcutItem.openSettings.rawValue,
                localizedTitle: L10n.ShortcutItem.OpenSettings.title,
                localizedSubtitle: nil,
                icon: .init(systemSymbol: .gear)
            )]
            return
        }

        let magicItemProvider = Current.magicItemProvider()
        magicItemProvider.loadInformation { _ in
            let config = (try? AppIconShortcutConfig.config()) ?? AppIconShortcutConfig()
            let shortcutItems = config.items.prefix(maximumShortcutItems).enumerated().map { index, item in
                UIApplicationShortcutItem(
                    type: shortcutType(for: index),
                    localizedTitle: title(for: item, provider: magicItemProvider),
                    localizedSubtitle: subtitle(for: item, provider: magicItemProvider),
                    icon: icon(for: item, provider: magicItemProvider)
                )
            }
            DispatchQueue.main.async {
                UIApplication.shared.shortcutItems = shortcutItems
            }
        }
    }

    static func index(from shortcutType: String) -> Int? {
        guard shortcutType.hasPrefix(shortcutTypePrefix) else { return nil }
        return Int(shortcutType.dropFirst(shortcutTypePrefix.count))
    }

    private static func shortcutType(for index: Int) -> String {
        "\(shortcutTypePrefix)\(index)"
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
