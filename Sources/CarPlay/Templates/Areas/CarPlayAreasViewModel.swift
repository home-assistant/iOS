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
    private var currentTask: Task<Void, Never>?
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

        guard Current.api(for: server)?.connection != nil else {
            Current.Log.error("No API available to update CarPlayAreasViewModel")
            return
        }

        currentTask?.cancel()
        currentTask = Task {
            let areasAndEntities = await Current.areasProvider().fetchAreasAndItsEntities(for: server)
            await MainActor.run {
                self.updateAreas(allEntitiesPerArea: areasAndEntities, server: server)
            }
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        self.entities = entities
        entitiesListTemplate?.entitiesStateChange(serverId: serverId, entities: entities)
    }

    private func updateAreas(allEntitiesPerArea: [String: Set<String>], server: Server) {
        let areas = Current.areasProvider().areas[server.identifier.rawValue]
        let items = areas?.sorted(by: { a1, a2 in
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
        } ?? []

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
