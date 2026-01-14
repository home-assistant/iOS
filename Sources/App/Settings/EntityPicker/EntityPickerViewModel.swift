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

    // Cached lookups to avoid recomputation on every filter
    private var cachedEntityToArea: [String: String] = [:]
    private var cachedAreaIdToEntityIds: [String: Set<String>] = [:]
    private var cachedEntitiesByServer: [String: [HAAppEntity]] = [:]

    let domainFilter: Domain?
    private var filterTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(domainFilter: Domain?, selectedServerId: String?) {
        self.domainFilter = domainFilter
        self.selectedServerId = selectedServerId
        self.selectedDomainFilter = domainFilter?.rawValue
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

        // Recompute area-based caches when area data changes
        $areaData
            .sink { [weak self] _ in
                self?.rebuildAreaCaches()
            }
            .store(in: &cancellables)

        // Re-fetch server-specific data when server changes
        $selectedServerId
            .removeDuplicates()
            .sink { [weak self] serverId in
                guard let self else { return }
                // Clear server-specific cache when server changes
                cachedEntitiesByServer.removeAll()
                fetchServerData(for: serverId)
            }
            .store(in: &cancellables)
    }

    private func rebuildAreaCaches() {
        var entityToArea: [String: String] = [:]
        var areaIdToEntityIds: [String: Set<String>] = [:]
        for area in areaData {
            areaIdToEntityIds[area.areaId] = area.entities
            for entityId in area.entities {
                entityToArea[entityId] = area.name
            }
        }
        cachedEntityToArea = entityToArea
        cachedAreaIdToEntityIds = areaIdToEntityIds
    }

    private func entitiesForCurrentServer() -> [HAAppEntity] {
        guard let serverId = selectedServerId else { return [] }
        if let cached = cachedEntitiesByServer[serverId] {
            return cached
        }
        // Build and cache
        let result = entities.filter { $0.serverId == serverId }
        cachedEntitiesByServer[serverId] = result
        return result
    }

    private func fetchServerData(for serverId: String?) {
        guard let serverId else { return }
        do {
            registryEntities = try AppEntityRegistryListForDisplay.config(serverId: serverId)
            registryEntriesData = try AppEntityRegistry.config(serverId: serverId)
            deviceRegistryData = try AppDeviceRegistry.config(serverId: serverId)
            areaData = try AppArea.fetchAreas(for: serverId)
            rebuildAreaCaches()
            // Prime server cache for this server
            cachedEntitiesByServer[serverId] = entities.filter { $0.serverId == serverId }
            updateFilteredEntities()
        } catch {
            Current.Log.error("Failed to fetch server data for entity picker, error: \(error)")
        }
    }

    func fetchEntities() {
        do {
            entities = try HAAppEntity.config()
            groupByDomain()

            // Rebuild caches with current data
            rebuildAreaCaches()
            if let serverId = selectedServerId {
                cachedEntitiesByServer[serverId] = entities.filter { $0.serverId == serverId }
            }

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
        // Snapshot state needed for filtering
        let searchTerm = searchTerm
        let domainFilter = selectedDomainFilter
        let areaFilter = selectedAreaFilter
        let grouping = selectedGrouping
        let noAreaTitle = L10n.EntityPicker.List.Area.NoArea.title

        // Pull cached lookups
        let entityToArea = cachedEntityToArea
        let areaIdToEntityIds = cachedAreaIdToEntityIds

        // Get entities already filtered by server
        let serverScopedEntities = entitiesForCurrentServer()

        let filtered = await Task.detached(priority: .userInitiated) { () -> [String: [HAAppEntity]] in
            // Resolve area entity id set if filtering by area
            let areaEntityIds: Set<String>? = areaFilter.flatMap { areaIdToEntityIds[$0] }

            // First, filter entities by domain, area, and search
            let filteredEntities = serverScopedEntities.filter { entity in
                // Filter by domain if set
                if let domainFilter, entity.domain != domainFilter { return false }

                // Filter by area if set
                if let areaEntityIds, !areaEntityIds.contains(entity.entityId) { return false }

                // Filter by search term (only when 3+ chars)
                if searchTerm.count > 2 {
                    let lower = searchTerm.lowercased()
                    if !entity.name.lowercased().contains(lower), !entity.entityId.lowercased().contains(lower) {
                        return false
                    }
                }
                return true
            }

            // Group by selected grouping
            switch grouping {
            case .domain:
                return Dictionary(grouping: filteredEntities) { $0.domain }
            case .area:
                var result: [String: [HAAppEntity]] = [:]
                for entity in filteredEntities {
                    let areaName = entityToArea[entity.entityId] ?? noAreaTitle
                    result[areaName, default: []].append(entity)
                }
                // Ensure the "No Area" group appears last by moving it to the end
                if let noAreaGroup = result.removeValue(forKey: noAreaTitle) {
                    result[noAreaTitle] = noAreaGroup
                }
                return result
            }
        }.value

        await MainActor.run {
            self.filteredEntitiesByGroup = filtered
        }
    }
}
