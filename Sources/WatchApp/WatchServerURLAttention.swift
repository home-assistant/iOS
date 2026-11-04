import Foundation
import Shared

/// Computes which synced servers currently resolve NO usable URL from the watch (typically
/// internal-only servers whose security level can't be evaluated while the watch proxies through
/// the iPhone). Shared by the settings screen (per-server "Needs attention" warnings) and the home
/// screen (the attention dot on the settings gear).
enum WatchServerURLAttention {
    static func serverIdsNeedingAttention() async -> Set<String> {
        var needingAttention = Set<String>()
        for server in Current.servers.all where await server.activeURL() == nil {
            needingAttention.insert(server.identifier.rawValue)
        }
        return needingAttention
    }
}
