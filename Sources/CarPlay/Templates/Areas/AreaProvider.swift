import Foundation
import Shared

enum AreaProvider {
    static func getAllEntitiesFromArea(
        devicesAndAreas: [HADeviceAreaResponse],
        entitiesAndAreas: [HAEntityAreaResponse]
    ) -> [String: Set<String>] {
        /// area_id : [device_id]
        var areasAndDevicesDict: [String: [String]] = [:]

        // Get all devices from an area
        for device in devicesAndAreas {
            if let areaId = device.areaId, let deviceId = device.deviceId {
                if var deviceIds = areasAndDevicesDict[areaId] {
                    deviceIds.append(deviceId)
                    areasAndDevicesDict[areaId] = deviceIds
                } else {
                    areasAndDevicesDict[areaId] = [deviceId]
                }
            }
        }

        /// area_id : [entity_id]
        var areasAndEntitiesDict: [String: Set<String>] = [:]

        // Get all entities from an area
        for entity in entitiesAndAreas {
            if let areaId = entity.areaId, let entityId = entity.entityId {
                if var entityIds = areasAndEntitiesDict[areaId] {
                    entityIds.insert(entityId)
                    areasAndEntitiesDict[areaId] = entityIds
                } else {
                    areasAndEntitiesDict[areaId] = [entityId]
                }
            }
        }

        /// device_id : [entity_id]
        var deviceChildrenEntities: [String: [String]] = [:]

        // Get entities from a device
        for areaAndDevices in areasAndDevicesDict {
            for deviceId in areaAndDevices.value {
                deviceChildrenEntities[deviceId] = entitiesAndAreas.filter { $0.deviceId == deviceId }
                    .compactMap(\.entityId)
            }
        }

        // Add device children entities to dictionary of areas and entities
        deviceChildrenEntities.forEach { deviceAndChildren in
            guard let areaOfDevice = areasAndDevicesDict.first(where: { areaAndDevices in
                areaAndDevices.value.contains(deviceAndChildren.key)
            })?.key else { return }

            if var entityIds = areasAndEntitiesDict[areaOfDevice] {
                deviceAndChildren.value.forEach { entityIds.insert($0) }
                areasAndEntitiesDict[areaOfDevice] = entityIds
            } else {
                areasAndEntitiesDict[areaOfDevice] = Set(deviceAndChildren.value)
            }
        }

        return areasAndEntitiesDict
    }
}
