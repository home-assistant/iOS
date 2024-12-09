import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasViewModel {
    private var request: HACancellable?
    weak var templateProvider: CarPlayAreasZonesTemplate?

    var entitiesListTemplate: CarPlayEntitiesListTemplate?
    private var entities: HACachedStates?

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

        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to update CarPlayAreasViewModel")
            return
        }

        request?.cancel()
        request = connection.send(HATypedRequest<[HAAreaResponse]>.fetchAreas(), completion: { [weak self] result in
            switch result {
            case let .success(data):
                self?.fetchEntitiesForAreas(data, server: server)
            case let .failure(error):
                self?.templateProvider?.template.updateSections([])
                Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
            }
        })
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        self.entities = entities
        entitiesListTemplate?.entitiesStateChange(serverId: serverId, entities: entities)
    }

    private func fetchEntitiesForAreas(_ areas: [HAAreaResponse], server: Server) {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch entities for areas")
            return
        }

        request?.cancel()
        request = connection.send(
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
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch devices for areas")
            return
        }

        request?.cancel()
        request = connection.send(
            HATypedRequest<[HADeviceAreaResponse]>.fetchDevicesWithAreas(),
            completion: { [weak self] result in
                switch result {
                case let .success(data):
                    self?.updateAreas(areas, entitiesAndAreas: entitiesWithAreas, devicesAndAreas: data, server: server)
                case let .failure(error):
                    self?.templateProvider?.template.updateSections([])
                    Current.Log.error(userInfo: ["Failed to retrieve areas and devices": error.localizedDescription])
                }
            }
        )
    }

    private func updateAreas(
        _ areas: [HAAreaResponse],
        entitiesAndAreas: [HAEntityAreaResponse],
        devicesAndAreas: [HADeviceAreaResponse],
        server: Server
    ) {
        let allEntitiesPerArea = AreaProvider.getAllEntitiesFromArea(
            devicesAndAreas: devicesAndAreas,
            entitiesAndAreas: entitiesAndAreas
        )

        let items = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).compactMap { area -> CPListItem? in
            guard let entityIdsForAreaId = allEntitiesPerArea[area.areaId] else { return nil }
            let icon = MaterialDesignIcons(
                serversideValueNamed: area.icon ?? "mdi:circle"
            ).carPlayIcon()
            let item = CPListItem(text: area.name, detailText: nil, image: icon)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.listItemHandler(area: area, entityIdsForAreaId: Array(entityIdsForAreaId), server: server)
                completion()
            }
            return item
        }

        templateProvider?.paginatedList.updateItems(items: items)
    }

    // swiftlint:enable cyclomatic_complexity

    private func listItemHandler(area: HAAreaResponse, entityIdsForAreaId: [String], server: Server) {
        guard let entities else { return }
        entitiesListTemplate = CarPlayEntitiesListTemplate.build(
            title: area.name,
            filterType: .areaId(entityIds: entityIdsForAreaId),
            server: server,
            entitiesCachedStates: entities
        )
        guard let entitiesListTemplate else { return }
        templateProvider?.presentEntitiesList(template: entitiesListTemplate)
    }
}
