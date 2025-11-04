import Foundation
import HAKit
import Shared

protocol AreasServiceProtocol {
    func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>]
    func area(for areaId: String, serverId: String) -> HAAreaResponse?
}

final class AreasService: AreasServiceProtocol {
    private var request: HACancellable?
    /// [ServerId: [HAAreaResponse]]
    private var areas: [String: [HAAreaResponse]] = [:]

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
            let allEntitiesPerArea = AreaProvider.getAllEntitiesFromArea(
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
}
