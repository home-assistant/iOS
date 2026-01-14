import Combine
import Foundation
import Shared

enum EntityGrouping: String, CaseIterable, Identifiable {
    case domain
    case area

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .domain: return L10n.EntityPicker.Filter.Domain.title
        case .area: return L10n.EntityPicker.Filter.Area.title
        }
    }
}

final class EntityPickerViewModel: ObservableObject {
    @Published var entities: [HAAppEntity] = []
    @Published var registryEntities: [AppEntityRegistryListForDisplay] = []
    @Published var registryEntriesData: [AppEntityRegistry] = []
    @Published var deviceRegistryData: [AppDeviceRegistry] = []
    @Published var areaData: [AppArea] = []
    @Published var showList = false
    @Published var searchTerm = ""
    @Published var selectedServerId: String?
    @Published var selectedDomainFilter: String? = nil
    @Published var selectedAreaFilter: String? = nil
    @Published var selectedGrouping: EntityGrouping = .area
    @Published var entitiesByDomain: [String: [HAAppEntity]] = [:]
    @Published var filteredEntitiesByGroup: [String: [HAAppEntity]] = [:]

    let domainFilter: Domain?
    private var filterTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(domainFilter: Domain?, selectedServerId: String?) {
        self.domainFilter = domainFilter
        self.selectedServerId = selectedServerId
        setupFiltering()
    }

    private func setupFiltering() {
        // Observe changes to filtering properties and update filtered results
        Publishers.CombineLatest4($searchTerm, $selectedServerId, $selectedDomainFilter, $selectedAreaFilter)
            .combineLatest($selectedGrouping)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateFilteredEntities()
            }
            .store(in: &cancellables)

        // Re-fetch server-specific data when server changes
        $selectedServerId
            .removeDuplicates()
            .sink { [weak self] serverId in
                self?.fetchServerData(for: serverId)
            }
            .store(in: &cancellables)
    }

    private func fetchServerData(for serverId: String?) {
        guard let serverId else { return }
        do {
            registryEntities = try AppEntityRegistryListForDisplay.config(serverId: serverId)
            registryEntriesData = try AppEntityRegistry.config(serverId: serverId)
            deviceRegistryData = try AppDeviceRegistry.config(serverId: serverId)
            areaData = try AppArea.fetchAreas(for: serverId)
            updateFilteredEntities()
        } catch {
            Current.Log.error("Failed to fetch server data for entity picker, error: \(error)")
        }
    }

    func fetchEntities() {
        do {
            entities = try HAAppEntity.config()
            groupByDomain()

            // Fetch server-specific data if a server is already selected
            if let serverId = selectedServerId {
                fetchServerData(for: serverId)
            } else {
                updateFilteredEntities()
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

    private func updateFilteredEntities() {
        filterTask?.cancel()
        filterTask = Task {
            await performFiltering()
        }
    }

    private func performFiltering() async {
        let allEntities = entities
        let searchTerm = searchTerm
        let serverId = selectedServerId
        let domainFilter = selectedDomainFilter
        let areaFilter = selectedAreaFilter
        let areas = areaData
        let grouping = selectedGrouping

        let filtered = await Task.detached(priority: .userInitiated) { () -> [String: [HAAppEntity]] in
            // Find the selected area's entity IDs if an area filter is set
            let areaEntityIds: Set<String>?
            if let areaFilter,
               let selectedArea = areas.first(where: { $0.areaId == areaFilter }) {
                areaEntityIds = selectedArea.entities
            } else {
                areaEntityIds = nil
            }

            // First, filter all entities
            let filteredEntities = allEntities.filter { entity in
                // Filter by server
                guard entity.serverId == serverId else { return false }

                // Filter by domain if set
                if let domainFilter, entity.domain != domainFilter {
                    return false
                }

                // Filter by area if set
                if let areaEntityIds {
                    guard areaEntityIds.contains(entity.entityId) else { return false }
                }

                // Filter by search term
                if searchTerm.count > 2 {
                    return entity.name.lowercased().contains(searchTerm.lowercased()) ||
                        entity.entityId.lowercased().contains(searchTerm.lowercased())
                }

                return true
            }

            // Group by selected grouping
            var result: [String: [HAAppEntity]] = [:]

            switch grouping {
            case .domain:
                result = Dictionary(grouping: filteredEntities) { $0.domain }

            case .area:
                // Create a lookup from entity ID to area name
                var entityToArea: [String: String] = [:]
                for area in areas {
                    for entityId in area.entities {
                        entityToArea[entityId] = area.name
                    }
                }

                // Group entities by area
                for entity in filteredEntities {
                    let areaName = entityToArea[entity.entityId] ?? "No Area"
                    result[areaName, default: []].append(entity)
                }
            }

            return result
        }.value

        await MainActor.run {
            self.filteredEntitiesByGroup = filtered
        }
    }
}
