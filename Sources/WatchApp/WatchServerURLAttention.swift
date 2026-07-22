import Foundation
import Shared

/// Computes which synced servers currently resolve NO usable URL from the watch (typically
/// internal-only servers whose security level can't be evaluated while the watch proxies through
/// the iPhone). Shared by the settings screen (per-server "Needs attention" warnings) and the home
/// screen (the attention dot on the settings gear).
enum WatchServerURLAttention {
    static func serverIdsNeedingAttention() async -> Set<String> {
        // The direct-sync experiment keeps its own record of servers it couldn't reach on the
        // last sync; fold it in only while that option is on.
        var needingAttention = WatchUserDefaults.shared.directDatabaseSyncEnabled
            ? WatchUserDefaults.shared.directSyncNoReachableURLServerIds
            : Set<String>()
        for server in Current.servers.all where await server.activeURL() == nil {
            needingAttention.insert(server.identifier.rawValue)
        }
        return needingAttention
    }
}
