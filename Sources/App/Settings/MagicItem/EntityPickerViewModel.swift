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

    let domainFilter: Domain?

    init(domainFilter: Domain?) {
        self.domainFilter = domainFilter
    }

    func fetchEntities() {
        do {
            var newEntities = try HAAppEntity.config()
            if let domainFilter {
                newEntities = newEntities.filter({ entity in
                    entity.domain == domainFilter.rawValue
                })
            }
            entities = newEntities

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
}
