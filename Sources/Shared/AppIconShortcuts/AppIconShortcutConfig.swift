import Foundation
import GRDB

public struct AppIconShortcutConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var appIconShortcutConfigId = "app-icon-shortcut-config"
    public var id = AppIconShortcutConfig.appIconShortcutConfigId
    public var items: [MagicItem] = []

    public init(
        id: String = AppIconShortcutConfig.appIconShortcutConfigId,
        items: [MagicItem] = []
    ) {
        self.id = id
        self.items = items
    }

    public static func config() throws -> AppIconShortcutConfig? {
        try Current.database().read { db in
            try AppIconShortcutConfig.fetchOne(db)
        }
    }
}
