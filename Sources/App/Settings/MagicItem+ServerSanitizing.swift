import Foundation
import Shared

extension [MagicItem] {
    /// Drops items belonging to a server this device does not know about, recursing into folders.
    ///
    /// Shared by the per-feature `DebugDatabaseTransfer` and the whole-app `AppConfigurationTransfer`:
    /// both refuse to restore configuration pointing at a server that is not signed in here, because
    /// such an item can never resolve to anything.
    func sanitized(knownServerIds: Set<String>) -> [MagicItem] {
        compactMap { item in
            var item = item
            if item.type == .folder {
                item.items = item.items?.sanitized(knownServerIds: knownServerIds)
                return item
            }
            guard item.serverId.isEmpty || knownServerIds.contains(item.serverId) else { return nil }
            return item
        }
    }
}
