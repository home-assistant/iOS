import Foundation
import GRDB

public extension HAAppEntity {
    var area: AppArea? {
        do {
            let areas = try AppArea.fetchAreas(for: serverId)

            return areas.first { area in
                area.entities.contains(entityId)
            }
        } catch {
            Current.Log.error("Failed to fetch areas for entity \(entityId): \(error)")
            return nil
        }
    }

    var device: AppDeviceRegistry? {
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

public extension [HAAppEntity] {
    /// Creates a mapping from entity IDs to their associated areas for a given server.
    /// - Parameter serverId: The server identifier to filter areas by.
    /// - Returns: A dictionary mapping entity IDs to their corresponding `AppArea` objects.
    func areasMap(for serverId: String) -> [String: AppArea] {
        do {
            let areas = try AppArea.fetchAreas(for: serverId)

            var entityToAreaMap: [String: AppArea] = [:]

            // Iterate through areas and map each entity to its area
            for area in areas {
                for entityId in area.entities {
                    entityToAreaMap[entityId] = area
                }
            }

            return entityToAreaMap
        } catch {
            Current.Log.error("Failed to fetch areas for mapping: \(error)")
            return [:]
        }
    }

    /// Creates a mapping from entity IDs to their associated devices for a given server.
    /// - Parameter serverId: The server identifier to filter entities and devices by.
    /// - Returns: A dictionary mapping entity IDs to their corresponding `AppDeviceRegistry` objects.
    func devicesMap(for serverId: String) -> [String: AppDeviceRegistry] {
        do {
            // Fetch all entity registries for the server
            let entityRegistries = try Current.database().read { db in
                try AppEntityRegistry
                    .filter(Column(DatabaseTables.EntityRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }

            // Fetch all devices for the server
            let devices = try Current.database().read { db in
                try AppDeviceRegistry
                    .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }

            // Create device lookup by deviceId
            let devicesByDeviceId = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0) })

            // Map entity IDs to devices
            var entityToDeviceMap: [String: AppDeviceRegistry] = [:]

            for entityRegistry in entityRegistries {
                guard let entityId = entityRegistry.entityId,
                      let deviceId = entityRegistry.deviceId,
                      let device = devicesByDeviceId[deviceId] else {
                    continue
                }
                entityToDeviceMap[entityId] = device
            }

            return entityToDeviceMap
        } catch {
            Current.Log.error("Failed to fetch devices for mapping: \(error)")
            return [:]
        }
    }
}
