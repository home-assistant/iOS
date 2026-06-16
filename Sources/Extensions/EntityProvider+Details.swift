import Foundation
import GRDB

/// Builds the secondary "context" line (`Area • Device`) shown under an entity name in pickers.
///
/// This is the single source of truth shared by the in-app `EntityPicker` and every AppIntent
/// based picker (widgets, controls, App Shortcuts) so the context shown stays consistent across
/// the whole app, matching how Home Assistant core/frontend present entities.
public enum EntityContextSubtitle {
    /// - Parameters:
    ///   - areaName: The area the entity belongs to, if any.
    ///   - deviceName: The device the entity belongs to, if any. Omitted when it merely repeats the entity name.
    ///   - entityName: The entity's resolved display name (used to avoid echoing it as the device name).
    ///   - entityId: The entity id, used as a last-resort context when no area/device is available.
    ///   - domain: The entity's domain. Used to decide whether the entity id fallback is meaningful.
    ///   - fallbackToEntityId: When `true`, returns the entity id if no area/device context exists.
    /// - Returns: The context line, or `nil` when there's nothing meaningful to show (so callers can
    ///   omit the subtitle entirely — e.g. a script/scene/automation with no area or device).
    public static func make(
        areaName: String?,
        deviceName: String?,
        entityName: String,
        entityId: String,
        domain: Domain?,
        fallbackToEntityId: Bool = true
    ) -> String? {
        var parts: [String] = []
        if let areaName, !areaName.isEmpty {
            parts.append(areaName)
        }
        if let deviceName, !deviceName.isEmpty,
           deviceName.range(of: entityName, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            parts.append(deviceName)
        }
        guard parts.isEmpty else {
            return parts.joined(separator: " • ")
        }
        // No area/device context available.
        if let domain, [.script, .scene, .automation].contains(domain) {
            return nil
        }
        return fallbackToEntityId ? entityId : nil
    }
}

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
                try EntityRegistryListForDisplay.Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.entityId.rawValue) == entityId)
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

    /// The secondary context line shown under the entity name (`Area • Device`).
    var contextualSubtitle: String? {
        EntityContextSubtitle.make(
            areaName: area?.name,
            deviceName: device?.name,
            entityName: name,
            entityId: entityId,
            domain: Domain(rawValue: domain)
        )
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
                try EntityRegistryListForDisplay.Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
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
                guard let deviceId = entityRegistry.deviceId,
                      let device = devicesByDeviceId[deviceId] else {
                    continue
                }
                entityToDeviceMap[entityRegistry.entityId] = device
            }

            return entityToDeviceMap
        } catch {
            Current.Log.error("Failed to fetch devices for mapping: \(error)")
            return [:]
        }
    }
}
