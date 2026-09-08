import Foundation

public struct RemoteMediaSelection: Codable, Equatable, Sendable {
    public let serverId: String
    public let entityId: String

    public init(serverId: String, entityId: String) {
        self.serverId = serverId
        self.entityId = entityId
    }

    /// Length-prefix the server identifier so distinct server/entity pairs cannot collide.
    public var id: String { "\(serverId.utf8.count):\(serverId)\(entityId)" }
}
