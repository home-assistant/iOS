import Foundation
import GRDB

/// Provides device class information for entities
public enum DeviceClassProvider {
    /// Returns the device class for a given entity
    /// - Parameters:
    ///   - entityId: The entity ID
    ///   - serverId: The server ID
    /// - Returns: The device class for the entity, or `.unknown` if not found
    public static func deviceClass(for entityId: String, serverId: String) -> DeviceClass {
        do {
            let entity = try Current.database().read { db in
                try HAAppEntity
                    .filter(
                        Column(DatabaseTables.AppEntity.entityId.rawValue) == entityId &&
                            Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId
                    )
                    .fetchOne(db)
            }
            return entity?.deviceClass ?? .unknown
        } catch {
            Current.Log.error("Failed to load device class for \(entityId): \(error)")
            return .unknown
        }
    }
}
