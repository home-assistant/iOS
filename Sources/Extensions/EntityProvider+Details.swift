import Foundation
import GRDB
import Shared

extension HAAppEntity {
    func area(serverId: String) -> AppArea? {
        do {
            let areas = try Current.database().read { _ in
                try AppArea.fetchAreas(for: serverId)
            }

            return areas.first { area in
                area.entities.contains(entityId)
            }
        } catch {
            Current.Log.error("Failed to fetch areas for entity \(entityId): \(error)")
            return nil
        }
    }

    func device(serverId: String) -> AppDeviceRegistry? {
        do {
            let entityRegistry = try Current.database().read { db in
                try AppEntityRegistry
                    .filter(Column(DatabaseTables.EntityRegistry.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.EntityRegistry.entityId.rawValue) == entityId)
                    .fetchOne(db)
            }
            let deviceId = entityRegistry?.deviceId
            let device = try Current.database().read { db in
                try AppDeviceRegistry
                    .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.DeviceRegistry.deviceId.rawValue) == deviceId)
                    .fetchOne(db)
            }
            return device
        } catch {
            Current.Log.error("Failed to fetch device for entity \(entityId): \(error)")
            return nil
        }
    }
}
