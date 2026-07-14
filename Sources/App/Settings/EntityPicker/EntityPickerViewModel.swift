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
    @Published var deviceRegistryData: [AppDeviceRegistry] = []
    @Published var areaData: [AppArea] = []
    @Published var showList = false
    @Published var searchTerm = ""
    @Published var selectedServerId: String?
    @Published var selectedDomainFilter: String? = nil
    @Published var selectedAreaFilter: String? = nil
    @Published var selectedGrouping: EntityGrouping = .area
    @Published var entitiesByDomain: [String: [HAAppEntity]] = [:]
    @Published var filteredGroups: [EntityPickerGroup] = []

    // Cached lookups to avoid recomputation on every filter
    private var cachedEntityToArea: [String: String] = [:]
    private var cachedAreaIdToEntityIds: [String: Set<String>] = [:]
    private var cachedEntitiesByServer: [String: [HAAppEntity]] = [:]
    private var fuzzyIndex: EntityFuzzySearchIndex?

    let domainFilter: [Domain]?
    private var filterTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Returns true if any filter (excluding server) has a non-default value
    var hasActiveFilters: Bool {
        let isDomainFilterActive = domainFilter == nil && selectedDomainFilter != nil
        let isAreaFilterActive = selectedAreaFilter != nil
        let isGroupingFilterActive = selectedGrouping != .area
        return isDomainFilterActive || isAreaFilterActive || isGroupingFilterActive
    }

    /// Resets all filters (except server) to their default values
    func resetFilters() {
        selectedDomainFilter = nil
        selectedAreaFilter = nil
        selectedGrouping = .area
    }

    init(domainFilter: [Domain]?, selectedServerId: String?) {
        self.domainFilter = domainFilter
        self.selectedServerId = selectedServerId
        self.selectedDomainFilter = nil
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
            deviceRegistryData = try AppDeviceRegistry.config(serverId: serverId)
            areaData = try AppArea.fetchAreas(for: serverId)
            rebuildAreaCaches()
            // Prime server cache for this server
            cachedEntitiesByServer[serverId] = entities.filter { $0.serverId == serverId }
            rebuildFuzzyIndex(for: serverId)
            updateFilteredEntities()
        } catch {
            Current.Log.error("Failed to fetch server data for entity picker, error: \(error)")
        }
    }

    private func rebuildFuzzyIndex(for serverId: String) {
        let serverEntities = entities.filter { $0.serverId == serverId }
        fuzzyIndex = EntityFuzzySearchIndex(entities: serverEntities, serverId: serverId)
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
            let allowedDomains = Set(domainFilter.map(\.rawValue))
            groups = groups.filter { allowedDomains.contains($0.key) }
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
        let searchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        let presetDomains = domainFilter.map { Set($0.map(\.rawValue)) }
        let selectedDomainFilter = selectedDomainFilter
        let areaFilter = selectedAreaFilter
        let grouping = selectedGrouping
        let noAreaTitle = L10n.EntityPicker.List.Area.NoArea.title

        // Pull cached lookups
        let entityToArea = cachedEntityToArea
        let areaIdToEntityIds = cachedAreaIdToEntityIds

        // Get entities already filtered by server
        let serverScopedEntities = entitiesForCurrentServer()
        let fuzzyIndex = fuzzyIndex

        let groups = await Task.detached(priority: .userInitiated) { () -> [EntityPickerGroup] in
            let areaEntityIds: Set<String>? = areaFilter.flatMap { areaIdToEntityIds[$0] }

            func passesStructuredFilters(_ entity: HAAppEntity) -> Bool {
                if let presetDomains, !presetDomains.contains(entity.domain) { return false }
                if let selectedDomainFilter, entity.domain != selectedDomainFilter { return false }
                if let areaEntityIds, !areaEntityIds.contains(entity.entityId) { return false }
                return true
            }

            let isSearching = !searchTerm.isEmpty
            let baseEntities: [HAAppEntity] = isSearching
                ? (fuzzyIndex?.search(searchTerm) ?? [])
                : serverScopedEntities
            let filteredEntities = baseEntities.filter(passesStructuredFilters)

            switch grouping {
            case .domain:
                return Self.groupPreservingOrder(filteredEntities, sortAlphabetically: !isSearching) { $0.domain }
            case .area:
                return Self.groupPreservingOrder(
                    filteredEntities,
                    sortAlphabetically: !isSearching,
                    lastGroupTitle: noAreaTitle
                ) { entityToArea[$0.entityId] ?? noAreaTitle }
            }
        }.value

        await MainActor.run {
            self.filteredGroups = groups
        }
    }

    private static func groupPreservingOrder(
        _ entities: [HAAppEntity],
        sortAlphabetically: Bool,
        lastGroupTitle: String? = nil,
        keyFor: (HAAppEntity) -> String
    ) -> [EntityPickerGroup] {
        var order: [String] = []
        var grouped: [String: [HAAppEntity]] = [:]
        for entity in entities {
            let key = keyFor(entity)
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(entity)
        }

        if sortAlphabetically {
            order.sort(by: <)
            if let lastGroupTitle, let index = order.firstIndex(of: lastGroupTitle) {
                order.remove(at: index)
                order.append(lastGroupTitle)
            }
        }

        return order.map { EntityPickerGroup(title: $0, entities: grouped[$0] ?? []) }
    }

    // MARK: - Test helpers (DEBUG only)

    #if DEBUG
    /// Exposes private groupByDomain for unit tests
    func _test_groupByDomain() {
        groupByDomain()
    }

    /// Exposes private updateFilteredEntities for unit tests
    func _test_updateFilteredEntities() {
        updateFilteredEntities()
    }
    #endif
}
