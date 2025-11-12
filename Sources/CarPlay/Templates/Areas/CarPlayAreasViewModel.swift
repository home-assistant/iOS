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
            // Fetch areas from database instead of always fetching from API
            let areas: [AppArea]
            do {
                areas = try AppArea.fetchAreas(for: server.identifier.rawValue)
            } catch {
                Current.Log.error("Failed to fetch areas from database: \(error.localizedDescription)")
                areas = []
            }

            await MainActor.run {
                self.updateAreas(areas: areas, server: server)
            }
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        self.entities = entities
        entitiesListTemplate?.entitiesStateChange(serverId: serverId, entities: entities)
    }

    @MainActor
    private func updateAreas(areas: [AppArea], server: Server) {
        let items = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).compactMap { area -> CPListItem? in
            // Skip areas with no entities
            guard !area.entities.isEmpty else { return nil }

            let icon = MaterialDesignIcons(
                serversideValueNamed: area.icon ?? "mdi:circle"
            ).carPlayIcon()
            let item = CPListItem(text: area.name, detailText: nil, image: icon)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.listItemHandler(area: area, server: server)
                completion()
            }
            return item
        }

        templateProvider?.paginatedList.updateItems(items: items)
    }

    // swiftlint:enable cyclomatic_complexity

    private func listItemHandler(area: AppArea, server: Server) {
        guard let entities else { return }
        entitiesListTemplate = CarPlayEntitiesListTemplate.build(
            title: area.name,
            filterType: .areaId(entityIds: Array(area.entities)),
            server: server,
            entitiesCachedStates: entities
        )
        guard let entitiesListTemplate else { return }
        templateProvider?.presentEntitiesList(template: entitiesListTemplate)
    }
}
