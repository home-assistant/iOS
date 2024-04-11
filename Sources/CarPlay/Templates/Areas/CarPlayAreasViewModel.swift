import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasViewModel {
    private var request: HACancellable?
    weak var templateProvider: CarPlayAreasZonesTemplate?

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    func cancelRequest() {
        request?.cancel()
    }

    func update() {
        guard let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first else {
            templateProvider?.template.updateSections([])
            return
        }

        let api = Current.api(for: server)

        request?.cancel()
        request = api.connection.send(HATypedRequest<[HAAreaResponse]>.fetchAreas(), completion: { [weak self] result in
            switch result {
            case let .success(data):
                self?.fetchEntitiesForAreas(data, server: server)
            case let .failure(error):
                self?.templateProvider?.template.updateSections([])
                Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
            }
        })
    }

    private func fetchEntitiesForAreas(_ areas: [HAAreaResponse], server: Server) {
        let api = Current.api(for: server)

        request?.cancel()
        request = api.connection.send(
            HATypedRequest<[HAEntityAreaResponse]>.fetchEntitiesWithAreas(),
            completion: { [weak self] result in
                switch result {
                case let .success(data):
                    self?.fetchDeviceForAreas(areas, entitiesWithAreas: data, server: server)
                case let .failure(error):
                    self?.templateProvider?.template.updateSections([])
                    Current.Log.error(userInfo: ["Failed to retrieve areas and entities": error.localizedDescription])
                }
            }
        )
    }

    private func fetchDeviceForAreas(
        _ areas: [HAAreaResponse],
        entitiesWithAreas: [HAEntityAreaResponse],
        server: Server
    ) {
        let api = Current.api(for: server)

        request?.cancel()
        request = api.connection.send(
            HATypedRequest<[HADeviceAreaResponse]>.fetchDevicesWithAreas(),
            completion: { [weak self] result in
                switch result {
                case let .success(data):
                    self?.updateAreas(areas, areasAndEntities: entitiesWithAreas, devicesAndAreas: data, server: server)
                case let .failure(error):
                    self?.templateProvider?.template.updateSections([])
                    Current.Log.error(userInfo: ["Failed to retrieve areas and devices": error.localizedDescription])
                }
            }
        )
    }

    // swiftlint:disable cyclomatic_complexity
    private func updateAreas(
        _ areas: [HAAreaResponse],
        areasAndEntities: [HAEntityAreaResponse],
        devicesAndAreas: [HADeviceAreaResponse],
        server: Server
    ) {
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
        var areasAndEntitiesDict: [String: [String]] = [:]

        // Get all entities from an area
        for entity in areasAndEntities {
            if let areaId = entity.areaId, let entityId = entity.entityId {
                if var entityIds = areasAndEntitiesDict[areaId] {
                    entityIds.append(entityId)
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
                deviceChildrenEntities[deviceId] = areasAndEntities.filter { $0.deviceId == deviceId }
                    .compactMap(\.entityId)
            }
        }

        // Add device children entities to dictionary of areas and entities
        deviceChildrenEntities.forEach { deviceAndChildren in
            guard let areaOfDevice = areasAndDevicesDict.first(where: { areaAndDevices in
                areaAndDevices.value.contains(deviceAndChildren.key)
            })?.key else { return }

            if var entityIds = areasAndEntitiesDict[areaOfDevice] {
                entityIds.append(contentsOf: deviceAndChildren.value)
                areasAndEntitiesDict[areaOfDevice] = entityIds
            } else {
                areasAndEntitiesDict[areaOfDevice] = deviceAndChildren.value
            }
        }

        let items = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).compactMap { area -> CPListItem? in
            guard let entityIdsForAreaId = areasAndEntitiesDict[area.areaId] else { return nil }
            let item = CPListItem(text: area.name, detailText: nil)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.listItemHandler(area: area, entityIdsForAreaId: entityIdsForAreaId, server: server)
                completion()
            }
            return item
        }

        templateProvider?.paginatedList.updateItems(items: items)
    }

    // swiftlint:enable cyclomatic_complexity

    private func listItemHandler(area: HAAreaResponse, entityIdsForAreaId: [String], server: Server) {
        let entitiesCachedStates = Current.api(for: server).connection.caches.states
        let entitiesListTemplate = CarPlayEntitiesListTemplate.build(
            title: area.name,
            filterType: .areaId(entityIds: entityIdsForAreaId),
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        templateProvider?.presentEntitiesList(template: entitiesListTemplate)
    }
}
