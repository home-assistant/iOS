import Foundation
import Shared

final class EntityPickerViewModel: ObservableObject {
    @Published var entities: [HAAppEntity] = []
    @Published var registryEntities: [AppEntityRegistryListForDisplay] = []
    @Published var registryEntriesData: [AppEntityRegistry] = []
    @Published var deviceRegistryData: [AppDeviceRegistry] = []
    @Published var areaData: [AppArea] = []
    @Published var showList = false
    @Published var searchTerm = ""
    @Published var selectedServerId: String?
    @Published var entitiesByDomain: [String: [HAAppEntity]] = [:]

    let domainFilter: Domain?

    init(domainFilter: Domain?) {
        self.domainFilter = domainFilter
    }

    func fetchEntities() {
        do {
            entities = try HAAppEntity.config()
            groupByDomain()

            if let serverId = selectedServerId {
                registryEntities = try AppEntityRegistryListForDisplay.config(serverId: serverId)
                registryEntriesData = try AppEntityRegistry.config(serverId: serverId)
                deviceRegistryData = try AppDeviceRegistry.config(serverId: serverId)
                areaData = try AppArea.fetchAreas(for: serverId)
            }
        } catch {
            Current.Log.error("Failed to fetch entities for entity picker, error: \(error)")
        }
    }

    private func groupByDomain() {
        var groups = Dictionary(grouping: entities) { entity in
            entity.domain
        }

        if let domainFilter {
            groups = groups.filter { $0.key == domainFilter.rawValue }
        }

        entitiesByDomain = groups
    }
}
