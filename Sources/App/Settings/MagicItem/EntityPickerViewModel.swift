import Foundation
import Combine
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
    @Published var filteredEntitiesByDomain: [String: [HAAppEntity]] = [:]

    let domainFilter: Domain?
    private var filterTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(domainFilter: Domain?) {
        self.domainFilter = domainFilter
        setupFiltering()
    }

    private func setupFiltering() {
        // Observe changes to searchTerm and selectedServerId and update filtered results
        Publishers.CombineLatest($searchTerm, $selectedServerId)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateFilteredEntities()
            }
            .store(in: &cancellables)
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
            
            updateFilteredEntities()
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

    private func updateFilteredEntities() {
        filterTask?.cancel()
        filterTask = Task {
            await performFiltering()
        }
    }

    private func performFiltering() async {
        let entities = entitiesByDomain
        let searchTerm = searchTerm
        let serverId = selectedServerId

        let filtered = await Task.detached(priority: .userInitiated) { () -> [String: [HAAppEntity]] in
            var result: [String: [HAAppEntity]] = [:]
            
            for (domain, domainEntities) in entities {
                let filteredEntities = domainEntities.filter { entity in
                    if searchTerm.count > 2 {
                        return entity.serverId == serverId && (
                            entity.name.lowercased().contains(searchTerm.lowercased()) ||
                            entity.entityId.lowercased().contains(searchTerm.lowercased())
                        )
                    } else {
                        return entity.serverId == serverId
                    }
                }
                
                if !filteredEntities.isEmpty {
                    result[domain] = filteredEntities
                }
            }
            
            return result
        }.value

        await MainActor.run {
            self.filteredEntitiesByDomain = filtered
        }
    }
}
