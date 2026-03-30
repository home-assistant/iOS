import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasViewModel {
    private let condensedAreasPerRow = 6
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
            templateProvider?.updateAreaItems(items: [])
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
        let displayAreas = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).filter { area in
            // Skip areas with no entities
            !area.entities.isEmpty
        }

        if #available(iOS 26.0, *) {
            templateProvider?.updateAreaItems(items: condensedAreaItems(areas: displayAreas, server: server))
        } else {
            templateProvider?.updateAreaItems(items: listItems(areas: displayAreas, server: server))
        }
    }

    // swiftlint:enable cyclomatic_complexity

    @available(iOS 26.0, *)
    private func condensedAreaItems(areas: [AppArea], server: Server) -> [any CPListTemplateItem] {
        stride(from: 0, to: areas.count, by: condensedAreasPerRow).map { startIndex in
            let pageAreas = Array(areas[startIndex ..< min(startIndex + condensedAreasPerRow, areas.count)])
            let elements = pageAreas.map { area in
                CPListImageRowItemCondensedElement(
                    image: MaterialDesignIcons(
                        serversideValueNamed: area.icon ?? "mdi:circle"
                    ).image(
                        ofSize: CPListImageRowItemCondensedElement.maximumImageSize,
                        color: .haPrimary
                    ),
                    imageShape: .roundedRectangle,
                    title: area.name,
                    subtitle: nil,
                    accessorySymbolName: "chevron.right"
                )
            }

            let item = CPListImageRowItem(
                text: nil,
                condensedElements: elements,
                allowsMultipleLines: true
            )
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard pageAreas.indices.contains(index) else {
                    completion()
                    return
                }
                self?.listItemHandler(area: pageAreas[index], server: server)
                completion()
            }
            return item
        }
    }

    private func listItems(areas: [AppArea], server: Server) -> [any CPListTemplateItem] {
        areas.map { area in
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
    }

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
