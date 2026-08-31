import Combine
import Foundation
import Shared

enum EntityGrouping: String, CaseIterable, Identifiable {
    case domain
    case area
    case device

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .domain: return L10n.EntityPicker.Filter.GroupBy.domain
        case .area: return L10n.EntityPicker.Filter.GroupBy.area
        case .device: return L10n.EntityPicker.Filter.GroupBy.device
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
    @Published var isRefreshing = false
    @Published var refreshStatusText: String?
    /// `entity_id → context line` and `entity_id → glyph`, resolved for the whole server at once so
    /// that a scrolling row neither reads the database nor writes view state.
    @Published var subtitles: [String: String] = [:]
    @Published var icons: [String: MaterialDesignIcons] = [:]

    // Cached lookups to avoid recomputation on every filter
    /// `entity_id → device`, from the display entity registry of the selected server.
    private var entityToDevice: [String: AppDeviceRegistry] = [:]
    private var cachedEntityToArea: [String: String] = [:]
    private var cachedEntityToDeviceGroup: [String: GroupKey] = [:]
    private var cachedAreaIdToEntityIds: [String: Set<String>] = [:]
    private var cachedEntitiesByServer: [String: [HAAppEntity]] = [:]
    private var entitiesIncludingHidden: [HAAppEntity] = []
    private var fuzzyIndex: EntityFuzzySearchIndex?

    let domainFilter: [Domain]?
    private var filterTask: Task<Void, Never>?
    private var filterGeneration = 0
    private var rowContentTask: Task<Void, Never>?
    private var refreshTimeoutTask: Task<Void, Never>?
    private var minimumDisplayTask: Task<Void, Never>?
    private var refreshStartedAt: Date?
    private let minimumRefreshDisplaySeconds: TimeInterval = 1.5
    private var cancellables = Set<AnyCancellable>()

    /// Returns true if any filter (excluding server) has a non-default value
    var hasActiveFilters: Bool {
        let isDomainFilterActive = selectedDomainFilter != nil
        let isAreaFilterActive = selectedAreaFilter != nil
        let isGroupingFilterActive = selectedGrouping != .area
        return isDomainFilterActive || isAreaFilterActive || isGroupingFilterActive
    }

    /// The domains the user can narrow the list down to: the domains present in the current server's
    /// entities, already restricted to the caller's preset `domainFilter` when one was given.
    /// Contexts that allow a single domain (e.g. scripts) have nothing to pick, so the picker hides
    /// itself when this holds fewer than two domains.
    var selectableDomains: [String] {
        Array(entitiesByDomain.keys)
    }

    /// Resets all filters (except server) to their default values
    func resetFilters() {
        selectedDomainFilter = nil
        selectedAreaFilter = nil
        selectedGrouping = .area
    }

    init(domainFilter: [Domain]?, selectedServerId: String?, initialSearchTerm: String? = nil) {
        self.domainFilter = domainFilter
        self.selectedServerId = selectedServerId
        self.selectedDomainFilter = nil
        self.searchTerm = initialSearchTerm ?? ""
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
                // A refresh belongs to the previously selected server, so stop showing its progress here.
                clearRefreshing()
                fetchServerData(for: serverId)
            }
            .store(in: &cancellables)

        // Reload the list once our in-progress refresh of the selected server finishes. Guarded by
        // `isRefreshing` so unrelated background updates never mutate state mid-presentation.
        NotificationCenter.default.publisher(for: .appDatabaseUpdaterDidFinishRoutine)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, isRefreshing, matchesSelectedServer(notification) else { return }
                finishRefreshing()
                fetchEntities()
            }
            .store(in: &cancellables)

        // Surface the updater's current phase (entities/devices/areas) while a refresh is in progress.
        NotificationCenter.default.publisher(for: .appDatabaseUpdaterDidChangePhase)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, isRefreshing, matchesSelectedServer(notification) else { return }
                if let text = notification.userInfo?[AppDatabaseUpdaterUserInfo.phaseDescriptionKey] as? String {
                    refreshStatusText = text
                }
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

    private func rebuildDeviceCaches() {
        let devicesById = Dictionary(
            deviceRegistryData.map { ($0.deviceId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var entityToDeviceGroup: [String: GroupKey] = [:]
        for (entityId, device) in entityToDevice {
            // A device the registry gives no name to can't title a section; its entities join the
            // trailing "no device" one rather than each opening a nameless section of their own.
            guard let deviceName = device.resolvedName else { continue }
            let parent = device.parentDeviceId.flatMap { devicesById[$0] }
            let parentName = parent?.resolvedName
            // The family is keyed by the parent's id as well as its name, so two parents sharing a
            // name still keep their own children with them.
            entityToDeviceGroup[entityId] = GroupKey(
                id: device.deviceId,
                title: deviceName,
                sortKey: [
                    parentName ?? deviceName,
                    parent?.deviceId ?? device.deviceId,
                    parentName == nil ? "0" : "1",
                    deviceName,
                    device.deviceId,
                ].joined(separator: "\u{0}")
            )
        }
        cachedEntityToDeviceGroup = entityToDeviceGroup
    }

    private func rebuildRowContent(for serverId: String) {
        let serverEntities = cachedEntitiesByServer[serverId] ?? []
        // Cancelled rather than left to race: a rebuild started before the entities loaded would
        // otherwise be free to finish last and wipe what the populated one resolved.
        rowContentTask?.cancel()
        rowContentTask = Task.detached(priority: .userInitiated) { [weak self] in
            let subtitles = serverEntities.contextualSubtitles(for: serverId)
            let icons = serverEntities.reduce(into: [String: MaterialDesignIcons]()) { icons, entity in
                icons[entity.entityId] = entity.materialDesignIcon
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, selectedServerId == serverId else { return }
                self.subtitles = subtitles
                self.icons = icons
            }
        }
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
            entityToDevice = cachedEntitiesByServer[serverId]?.devicesMap(for: serverId) ?? [:]
            rebuildDeviceCaches()
            rebuildRowContent(for: serverId)
            rebuildFuzzyIndex(for: serverId)
            // The available domains belong to the server that is now selected, so a domain the
            // previous server had but this one doesn't is dropped instead of emptying the list.
            groupByDomain()
            if let pickedDomain = selectedDomainFilter, !entitiesByDomain.keys.contains(pickedDomain) {
                selectedDomainFilter = nil
            }
            updateFilteredEntities()
        } catch {
            Current.Log.error("Failed to fetch server data for entity picker, error: \(error)")
        }
    }

    private func rebuildFuzzyIndex(for serverId: String) {
        let serverEntities = entitiesIncludingHidden.filter { $0.serverId == serverId }
        fuzzyIndex = EntityFuzzySearchIndex(entities: serverEntities, serverId: serverId)
    }

    func fetchEntities() {
        do {
            entities = try HAAppEntity.config()
            entitiesIncludingHidden = try HAAppEntity.config(include: [.hidden])

            // Rebuild caches with current data before grouping, which reads the server cache.
            rebuildAreaCaches()
            if let serverId = selectedServerId {
                cachedEntitiesByServer[serverId] = entities.filter { $0.serverId == serverId }
            }
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

    @MainActor
    func refresh() async {
        guard !isRefreshing,
              let serverId = selectedServerId,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            return
        }

        isRefreshing = true
        refreshStartedAt = Current.date()

        guard await server.activeURL() != nil else {
            finishRefreshing()
            return
        }

        refreshStatusText = L10n.EntityPicker.Refresh.updating
        Current.appDatabaseUpdater.update(server: server, forceUpdate: true, showProgress: false)
        scheduleRefreshTimeout(30)
    }

    private func scheduleRefreshTimeout(_ timeout: TimeInterval) {
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            finishRefreshing()
        }
    }

    private func finishRefreshing() {
        let elapsed = refreshStartedAt.map { Current.date().timeIntervalSince($0) } ?? minimumRefreshDisplaySeconds
        let remaining = minimumRefreshDisplaySeconds - elapsed
        guard isRefreshing, remaining > 0 else {
            clearRefreshing()
            return
        }
        minimumDisplayTask?.cancel()
        minimumDisplayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            clearRefreshing()
        }
    }

    private func clearRefreshing() {
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil
        minimumDisplayTask?.cancel()
        minimumDisplayTask = nil
        refreshStartedAt = nil
        isRefreshing = false
        refreshStatusText = nil
    }

    private func matchesSelectedServer(_ notification: Notification) -> Bool {
        guard let server = notification.object as? Server else { return false }
        return server.identifier.rawValue == selectedServerId
    }

    private func groupByDomain() {
        // Scoped to the selected server so the domain filter never offers a domain that only exists
        // on another server (which would show an empty list).
        let scopedEntities = selectedServerId == nil ? entities : entitiesForCurrentServer()
        var groups = Dictionary(grouping: scopedEntities) { entity in
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
        filterGeneration &+= 1
        let generation = filterGeneration
        filterTask = Task {
            await performFiltering(generation: generation)
        }
    }

    @MainActor
    private func performFiltering(generation: Int) async {
        // Snapshot state needed for filtering
        let searchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        let presetDomains = domainFilter.map { Set($0.map(\.rawValue)) }
        let selectedDomainFilter = selectedDomainFilter
        let areaFilter = selectedAreaFilter
        let grouping = selectedGrouping
        let noAreaTitle = L10n.EntityPicker.List.Area.NoArea.title
        let noDeviceTitle = L10n.EntityPicker.List.Device.NoDevice.title

        // Pull cached lookups
        let entityToArea = cachedEntityToArea
        let entityToDeviceGroup = cachedEntityToDeviceGroup
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
                return Self.groupPreservingOrder(filteredEntities, sortAlphabetically: !isSearching) {
                    GroupKey(id: $0.domain, title: $0.domain)
                }
            case .area:
                return Self.groupPreservingOrder(
                    filteredEntities,
                    sortAlphabetically: !isSearching,
                    lastGroupId: noAreaTitle
                ) { entity in
                    let areaName = entityToArea[entity.entityId] ?? noAreaTitle
                    return GroupKey(id: areaName, title: areaName)
                }
            case .device:
                return Self.groupPreservingOrder(
                    filteredEntities,
                    sortAlphabetically: !isSearching,
                    lastGroupId: noDeviceTitle
                ) { entity in
                    entityToDeviceGroup[entity.entityId] ?? GroupKey(id: noDeviceTitle, title: noDeviceTitle)
                }
            }
        }.value

        // Back on the main actor: drop results from a superseded run so a slow older search can't
        // clobber a newer one.
        guard generation == filterGeneration else { return }
        filteredGroups = groups
    }

    /// How a section is keyed, titled and ordered, so a section can sort somewhere other than
    /// under its own title.
    private struct GroupKey {
        let id: String
        let title: String
        let sortKey: String

        init(id: String, title: String, sortKey: String? = nil) {
            self.id = id
            self.title = title
            self.sortKey = sortKey ?? title
        }
    }

    private static func groupPreservingOrder(
        _ entities: [HAAppEntity],
        sortAlphabetically: Bool,
        lastGroupId: String? = nil,
        keyFor: (HAAppEntity) -> GroupKey
    ) -> [EntityPickerGroup] {
        var order: [GroupKey] = []
        var grouped: [String: [HAAppEntity]] = [:]
        for entity in entities {
            let key = keyFor(entity)
            if grouped[key.id] == nil { order.append(key) }
            grouped[key.id, default: []].append(entity)
        }

        if sortAlphabetically {
            order.sort { $0.sortKey < $1.sortKey }
            if let lastGroupId, let index = order.firstIndex(where: { $0.id == lastGroupId }) {
                let last = order.remove(at: index)
                order.append(last)
            }
        }

        return order.map { EntityPickerGroup(id: $0.id, title: $0.title, entities: grouped[$0.id] ?? []) }
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

    /// Runs the filtering pipeline to completion so tests can assert on `filteredGroups` without racing
    /// the debounce/Task hop that `updateFilteredEntities` introduces. The generation guard in
    /// `performFiltering` ensures any still-running earlier task cannot clobber this result.
    @MainActor
    func _test_awaitFiltering() async {
        updateFilteredEntities()
        await filterTask?.value
    }
    #endif
}
