import Foundation

/// One server's areas that can be added to the watch configuration as an area entry, used by both
/// the iPhone and the on-watch add flows.
///
/// Only areas holding at least one watch-compatible entity are included — an entry to an area the
/// watch can't render anything for would always open an empty screen.
public struct WatchAddableAreaGroup: Identifiable {
    public let serverId: String
    public let serverName: String
    public let areas: [AppArea]

    public var id: String { serverId }

    public init(serverId: String, serverName: String, areas: [AppArea]) {
        self.serverId = serverId
        self.serverName = serverName
        self.areas = areas
    }

    /// Resolve the addable areas of the given servers, dropping servers that have none. Synchronous
    /// database work — call it off the main thread.
    public static func make(servers: [Server]) -> [WatchAddableAreaGroup] {
        servers.compactMap { server in
            let serverId = server.identifier.rawValue
            let areas = (try? AppArea.fetchWatchPopulatedAreas(for: serverId)) ?? []
            guard !areas.isEmpty else { return nil }
            return .init(serverId: serverId, serverName: server.info.name, areas: areas)
        }
    }
}
