import Foundation
import HAKit

public protocol AreasServiceProtocol {
    var areas: [String: [HAAreasRegistryResponse]] { get }
    func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>]
    func area(for areaId: String, serverId: String) -> HAAreasRegistryResponse?
}

final class AreasService: AreasServiceProtocol {
    static var shared: AreasServiceProtocol = AreasService()

    private var request: HACancellable?
    /// [ServerId: [HAAreasRegistryResponse]]
    var areas: [String: [HAAreasRegistryResponse]] = [:]

    func area(for areaId: String, serverId: String) -> HAAreasRegistryResponse? {
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
            request = connection.send(
                HATypedRequest<[HAAreasRegistryResponse]>.configAreasRegistry(),
                completion: { result in
                    switch result {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
                        continuation.resume(returning: [])
                    }
                }
            )
        }
        self.areas[server.identifier.rawValue] = areas
        if areas.isEmpty {
            Current.Log.verbose("No areas found on the server.")
            return [:]
        } else {
            let entitiesForAreas = await fetchEntitiesForAreas(areas, server: server)
            updatePropertiesInEntitiesDatabase(entitiesForAreas, serverId: server.identifier.rawValue)
            let deviceForAreas = await fetchDeviceForAreas(areas, entitiesWithAreas: entitiesForAreas, server: server)
            let allEntitiesPerArea = getAllEntitiesFromArea(
                devicesAndAreas: deviceForAreas,
                entitiesAndAreas: entitiesForAreas
            )

            return allEntitiesPerArea
        }
    }

    /// Updates the `hiddenBy` and `disabledBy` properties for entities in the local database based on the registry
    /// response.
    ///
    /// This method synchronizes the hidden and disabled states of entities from Home Assistant's entity registry
    /// with the local database. It fetches all entities (including hidden and disabled ones) from the database,
    /// matches them with the provided registry responses, and updates their `hiddenBy` and `disabledBy` properties
    /// to reflect the current state from the server.
    ///
    /// - Parameters:
    ///   - entitiesRegistryResponse: An array of entity registry responses from Home Assistant
    ///     containing the current `hiddenBy` and `disabledBy` states for each entity.
    ///   - serverId: The server identifier to filter entities by.
    ///
    /// - Note: This method includes hidden and disabled entities when fetching from the database to ensure
    ///   all entities can have their states updated.
    ///
    /// - Important: If the database write operation fails, an error will be logged but the method
    ///   will continue processing remaining entities.
    private func updatePropertiesInEntitiesDatabase(
        _ entitiesRegistryResponse: [EntityRegistryEntry],
        serverId: String
    ) {
        do {
            let entities = try HAAppEntity.config(include: [.all]).filter({ $0.serverId == serverId })

            for entity in entities {
                if let entityRegistry = entitiesRegistryResponse.first(where: { $0.entityId == entity.entityId }) {
                    var updatedEntity = entity
                    updatedEntity.hiddenBy = entityRegistry.hiddenBy
                    updatedEntity.disabledBy = entityRegistry.disabledBy
                    try Current.database().write { db in
                        try updatedEntity.update(db)
                    }
                }
            }
        } catch {
            Current.Log.error("Failed to update hiddenBy property in entities database: \(error.localizedDescription)")
        }
    }

    private func fetchEntitiesForAreas(
        _ areas: [HAAreasRegistryResponse],
        server: Server
    ) async -> [EntityRegistryEntry] {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch entities for areas")
            return []
        }

        request?.cancel()
        let entitiesForAreas = await withCheckedContinuation { continuation in
            request = connection.send(
                HATypedRequest<[EntityRegistryEntry]>.configEntityRegistryList(),
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
        _ areas: [HAAreasRegistryResponse],
        entitiesWithAreas: [EntityRegistryEntry],
        server: Server
    ) async -> [DeviceRegistryEntry] {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch devices for areas")
            return []
        }

        request?.cancel()
        let devicesForAreas = await withCheckedContinuation { continuation in
            request = connection.send(
                HATypedRequest<[DeviceRegistryEntry]>.configDeviceRegistryList(),
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
        devicesAndAreas: [DeviceRegistryEntry],
        entitiesAndAreas: [EntityRegistryEntry]
    ) -> [String: Set<String>] {
        /// area_id : [device_id]
        var areasAndDevicesDict: [String: [String]] = [:]

        // Get all devices from an area
        for device in devicesAndAreas {
            let deviceId = device.id
            if let areaId = device.areaId {
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

    #if DEBUG
    /// For testing purposes only
    public func testGetAllEntitiesFromArea(
        devicesAndAreas: [DeviceRegistryEntry],
        entitiesAndAreas: [EntityRegistryEntry]
    ) -> [String: Set<String>] {
        getAllEntitiesFromArea(devicesAndAreas: devicesAndAreas, entitiesAndAreas: entitiesAndAreas)
    }
    #endif
}
