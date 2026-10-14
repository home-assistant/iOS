import Foundation
import Shared
import Testing

/// Inputs written the way they actually arrive: Home Assistant attributes as the JSON a server sends,
/// parsed by `JSONSerialization` like every real caller's are.
enum RemoteMediaFixtures {
    static var entityId: RemoteMediaEntityId {
        get throws { try #require(RemoteMediaEntityId("media_player.living_room")) }
    }

    static func attributes(_ json: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [String: Any])
    }

    static func mapped(_ state: String = "playing", _ json: String = "{}") throws -> RemoteMediaEntityState {
        let entityId = try entityId
        let attributes = try attributes(json)
        return RemoteMediaSnapshotMapper.map(
            serverId: "server-1",
            entityId: entityId,
            state: state,
            attributes: attributes
        )
    }

    static func report(_ state: String = "playing", _ json: String = "{}") throws -> RemoteMediaSnapshot {
        try mapped(state, json).snapshot
    }
}
