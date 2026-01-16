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
            // Read entity and device registries from database instead of making API calls
            let entitiesForAreas = fetchEntitiesFromDatabase(serverId: server.identifier.rawValue)
            updatePropertiesInEntitiesDatabase(entitiesForAreas, serverId: server.identifier.rawValue)
            let deviceForAreas = fetchDevicesFromDatabase(serverId: server.identifier.rawValue)
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
    ///   - entitiesRegistryResponse: An array of entity registry entries from the database
    ///     containing the current `hiddenBy` and `disabledBy` states for each entity.
    ///   - serverId: The server identifier to filter entities by.
    ///
    /// - Note: This method includes hidden and disabled entities when fetching from the database to ensure
    ///   all entities can have their states updated.
    ///
    /// - Important: If the database write operation fails, an error will be logged but the method
    ///   will continue processing remaining entities.
    private func updatePropertiesInEntitiesDatabase(
        _ entitiesRegistryResponse: [AppEntityRegistry],
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

    private func fetchEntitiesFromDatabase(serverId: String) -> [AppEntityRegistry] {
        do {
            return try AppEntityRegistry.config(serverId: serverId)
        } catch {
            Current.Log.error("Failed to fetch entities from database: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchDevicesFromDatabase(serverId: String) -> [AppDeviceRegistry] {
        do {
            return try AppDeviceRegistry.config(serverId: serverId)
        } catch {
            Current.Log.error("Failed to fetch devices from database: \(error.localizedDescription)")
            return []
        }
    }

    private func getAllEntitiesFromArea(
        devicesAndAreas: [AppDeviceRegistry],
        entitiesAndAreas: [AppEntityRegistry]
    ) -> [String: Set<String>] {
        /// area_id : Set<device_id>
        var areasAndDevicesDict: [String: Set<String>] = [:]
        /// device_id : area_id (reverse lookup for O(1) access)
        var deviceToAreaMap: [String: String] = [:]

        // Build area->devices mapping and device->area reverse lookup
        for device in devicesAndAreas {
            if let areaId = device.areaId {
                areasAndDevicesDict[areaId, default: []].insert(device.deviceId)
                deviceToAreaMap[device.deviceId] = areaId
            }
        }

        /// area_id : Set<entity_id>
        var areasAndEntitiesDict: [String: Set<String>] = [:]
        /// device_id : Set<entity_id> (built in one pass)
        var deviceChildrenEntities: [String: Set<String>] = [:]

        // Single pass through entities: add to areas and build device->entities mapping
        for entity in entitiesAndAreas {
            guard let entityId = entity.entityId else { continue }

            // Add entity directly to its area
            if let areaId = entity.areaId {
                areasAndEntitiesDict[areaId, default: []].insert(entityId)
            }

            // Build device->entities mapping for later
            if let deviceId = entity.deviceId {
                deviceChildrenEntities[deviceId, default: []].insert(entityId)
            }
        }

        // Add device children entities to their areas (using reverse lookup)
        for (deviceId, entityIds) in deviceChildrenEntities {
            if let areaId = deviceToAreaMap[deviceId] {
                areasAndEntitiesDict[areaId, default: []].formUnion(entityIds)
            }
        }

        return areasAndEntitiesDict
    }

    #if DEBUG
    /// For testing purposes only
    public func testGetAllEntitiesFromArea(
        devicesAndAreas: [AppDeviceRegistry],
        entitiesAndAreas: [AppEntityRegistry]
    ) -> [String: Set<String>] {
        getAllEntitiesFromArea(devicesAndAreas: devicesAndAreas, entitiesAndAreas: entitiesAndAreas)
    }
    #endif
}
