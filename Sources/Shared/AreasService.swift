import Foundation
import HAKit

public protocol AreasServiceProtocol {
    var areas: [String: [HAAreaResponse]] { get }
    func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>]
    func area(for areaId: String, serverId: String) -> HAAreaResponse?
}

final class AreasService: AreasServiceProtocol {
    static var shared: AreasServiceProtocol = AreasService()

    private var request: HACancellable?
    /// [ServerId: [HAAreaResponse]]
    var areas: [String: [HAAreaResponse]] = [:]

    func area(for areaId: String, serverId: String) -> HAAreaResponse? {
        guard let areasForServer = areas[serverId] else {
            return nil
        }
        return areasForServer.first(where: { $0.areaId == areaId })
    }

    func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>] {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetchAreasAndItsEntities")
            return [:]
        }

        request?.cancel()
        let areas = await withCheckedContinuation { continuation in
            request = connection.send(HATypedRequest<[HAAreaResponse]>.fetchAreas(), completion: { result in
                switch result {
                case let .success(data):
                    continuation.resume(returning: data)
                case let .failure(error):
                    Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
                    continuation.resume(returning: [])
                }
            })
        }
        self.areas[server.identifier.rawValue] = areas
        if areas.isEmpty {
            Current.Log.verbose("No areas found on the server.")
            return [:]
        } else {
            let entitiesForAreas = await fetchEntitiesForAreas(areas, server: server)
            let deviceForAreas = await fetchDeviceForAreas(areas, entitiesWithAreas: entitiesForAreas, server: server)
            let allEntitiesPerArea = getAllEntitiesFromArea(
                devicesAndAreas: deviceForAreas,
                entitiesAndAreas: entitiesForAreas
            )

            return allEntitiesPerArea
        }
    }

    private func fetchEntitiesForAreas(_ areas: [HAAreaResponse], server: Server) async -> [HAEntityAreaResponse] {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch entities for areas")
            return []
        }

        request?.cancel()
        let entitiesForAreas = await withCheckedContinuation { continuation in
            request = connection.send(
                HATypedRequest<[HAEntityAreaResponse]>.fetchEntitiesWithAreas(),
                completion: { result in
                    switch result {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        Current.Log
                            .error(userInfo: ["Failed to retrieve areas and entities": error.localizedDescription])
                        continuation.resume(returning: [])
                    }
                }
            )
        }
        return entitiesForAreas
    }

    private func fetchDeviceForAreas(
        _ areas: [HAAreaResponse],
        entitiesWithAreas: [HAEntityAreaResponse],
        server: Server
    ) async -> [HADeviceAreaResponse] {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch devices for areas")
            return []
        }

        request?.cancel()
        let devicesForAreas = await withCheckedContinuation { continuation in
            request = connection.send(
                HATypedRequest<[HADeviceAreaResponse]>.fetchDevicesWithAreas(),
                completion: { result in
                    switch result {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        Current.Log
                            .error(userInfo: ["Failed to retrieve areas and devices": error.localizedDescription])
                        continuation.resume(returning: [])
                    }
                }
            )
        }
        return devicesForAreas
    }

    private func getAllEntitiesFromArea(
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
