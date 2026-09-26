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

    private static var databaseUpdateObserver: NSObjectProtocol?

    /// Publishes the configured items now and again each time the database updater finishes a
    /// server, so titles resolved before the entity table was synced (a fresh install, an imported
    /// configuration) catch up without waiting for the next launch.
    static func start() {
        if databaseUpdateObserver == nil {
            databaseUpdateObserver = NotificationCenter.default.addObserver(
                forName: .appDatabaseUpdaterDidFinishRoutine,
                object: nil,
                queue: .main
            ) { _ in
                update()
            }
        }
        update()
    }

    static func stop() {
        if let databaseUpdateObserver {
            NotificationCenter.default.removeObserver(databaseUpdateObserver)
        }
        databaseUpdateObserver = nil
    }

    static func update() {
        // `loadInformation` fetches every entity, area, and device row for every server
        // synchronously on the calling thread, and `update()` runs at app launch — keep that work
        // off the main thread. The resulting items are published back on main.
        //
        // It runs as protected work because launch is exactly when the user is most likely to
        // background the app again: on a plain queue those reads were the app's largest crash, the
        // process frozen mid-statement while holding the app-group SQLite file lock (0xdead10cc).
        AppDatabaseSuspension.performProtectedWork(named: .appIconShortcutItems) {
            let magicItemProvider = Current.magicItemProvider()
            magicItemProvider.loadInformation { entitiesPerServer in
                let config = (try? AppIconShortcutConfig.config()) ?? AppIconShortcutConfig()
                let items = Array(config.items.filter { $0.type != .unsupported }.prefix(maximumShortcutItems))
                // A failed entity read leaves the server out of the result entirely (one whose
                // entities were never synced still reports an empty list). Every title would then
                // fall back to a bare entity id, so keep what is published and let the next update
                // — the database updater finishing, or the next launch — try again.
                guard !hasUnreadableServer(for: items, entitiesPerServer: entitiesPerServer) else {
                    Current.Log.error("Keeping the published app icon shortcuts: entities could not be read")
                    return
                }
                let configuredShortcutItems = items
                    .map { item in
                        UIApplicationShortcutItem(
                            type: shortcutType(for: item),
                            localizedTitle: title(for: item, provider: magicItemProvider),
                            localizedSubtitle: subtitle(for: item, provider: magicItemProvider),
                            icon: icon(for: item, provider: magicItemProvider)
                        )
                    }
                // The forced items are published here, with the configured ones, rather than up
                // front: publishing them alone first would replace the user's shortcuts before the
                // guard above had a chance to keep them.
                let shortcutItems = Self.forcedShortcutItems + configuredShortcutItems
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

    private static func hasUnreadableServer(
        for items: [MagicItem],
        entitiesPerServer: [String: [HAAppEntity]]
    ) -> Bool {
        items.contains { item in
            entitiesPerServer[item.serverId] == nil
                && Current.servers.server(for: .init(rawValue: item.serverId)) != nil
        }
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
        case .script:
            return .init(systemSymbol: .applescriptFill)
        case .scene:
            return .init(systemSymbol: .sparkles)
        case .entity:
            return .init(systemSymbol: .rectangleAndPaperclip)
        case .folder:
            return .init(systemSymbol: .folderFill)
        case .area:
            // Areas can only be added to the watch, so this is never reached in practice.
            return .init(systemSymbol: .squareGrid2x2Fill)
        case .assistPipeline, .assistPrompt:
            return .init(systemSymbol: .micFill)
        case .complication:
            return .init(systemSymbol: .applewatch)
        case .unsupported:
            return nil
        }
    }
}
