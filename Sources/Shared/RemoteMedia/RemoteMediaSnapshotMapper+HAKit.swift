import HAKit
import HARemoteMedia

public extension RemoteMediaSnapshotMapper {
    /// Maps a HAKit entity, or returns `nil` unless it is a valid `media_player` entity.
    static func map(_ entity: HAEntity, serverId: String) -> RemoteMediaEntityState? {
        guard let entityId = RemoteMediaEntityId(entity.entityId) else { return nil }
        return map(
            serverId: serverId,
            entityId: entityId,
            state: entity.state,
            attributes: entity.attributes.dictionary
        )
    }
}
