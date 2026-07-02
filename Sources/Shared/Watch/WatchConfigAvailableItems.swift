import Foundation

/// The set of items a user can add to their watch configuration, built on the phone (which owns the
/// entity database) and sent to the watch in reply to `watchConfigAvailableItems`.
///
/// Each `Candidate` carries a fully-built `MagicItem` so the watch appends exactly what the phone
/// would have created (scripts/scenes/automations are stored as `type: .entity`), plus a resolved
/// `MagicItem.Info` for rendering the picker row.
public struct WatchConfigAvailableItems: WatchCodable {
    public struct Candidate: Codable, Equatable {
        public let item: MagicItem
        public let info: MagicItem.Info
        /// The `Floor • Area • Device` context line WITHOUT the server prefix (the user already picked
        /// the server in the add flow). Shown under the name in the picker, mirroring the iOS entity
        /// picker.
        public let contextSubtitle: String?

        public init(item: MagicItem, info: MagicItem.Info, contextSubtitle: String?) {
            self.item = item
            self.info = info
            self.contextSubtitle = contextSubtitle
        }
    }

    public struct ServerGroup: Codable, Equatable {
        public let serverId: String
        public let serverName: String
        public let candidates: [Candidate]

        public init(serverId: String, serverName: String, candidates: [Candidate]) {
            self.serverId = serverId
            self.serverName = serverName
            self.candidates = candidates
        }
    }

    public let servers: [ServerGroup]

    public init(servers: [ServerGroup]) {
        self.servers = servers
    }

    /// Every candidate across all server groups, flattened for search/enumeration.
    public var allCandidates: [Candidate] {
        servers.flatMap(\.candidates)
    }
}
