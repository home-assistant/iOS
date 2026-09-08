import Foundation
import HAKit

public extension RemoteMediaSnapshotMapper {
    /// Adapter for the host app's HAKit state subscription onto the shared mapping.
    ///
    /// The extension reaches the same mapping through `render_template`, so the foreground and
    /// background views of a player cannot disagree about what its attributes mean.
    static func map(_ entity: HAEntity, serverId: String) -> RemoteMediaEntityState? {
        map(
            entityId: entity.entityId,
            state: entity.state,
            attributes: entity.attributes.dictionary,
            serverId: serverId
        )
    }
}
