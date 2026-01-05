import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class HomeViewModel: ObservableObject {
    var groupedEntities: [RoomSection] = []
    var isLoading = false
    var errorMessage: String?
    var server: Server
    var entityStates: [String: HAEntity] = [:]
    var sectionOrder: [String] = []
    var hiddenEntityIds: Set<String> = []
    var selectedSectionIds: Set<String> = []
    var allowMultipleSelection: Bool = false
    var entityOrderByRoom: [String: [String]] = [:] // roomId -> [entityId]
    private var appEntities: [HAAppEntity] = []
    private var registryEntities: [AppEntityRegistryListForDisplay] = []
    struct RoomSection: Identifiable, Equatable {
        let id: String
        let name: String
        let entities: [HAEntity]
    }

    private let entityService = EntityDisplayService()

    init(server: Server) {
        self.server = server
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        do {
            // Does not include disabled and hidden entities, it will be used to filter HAEntity
            appEntities = try HAAppEntity.config().filter({ $0.serverId == server.identifier.rawValue })
            registryEntities = try AppEntityRegistryListForDisplay.config(serverId: server.identifier.rawValue)

            // Load hidden entities, section order, and filter settings BEFORE building sections
            let loadedHiddenEntities = await EntityDisplayService.loadHiddenEntities(for: server)
            hiddenEntityIds = loadedHiddenEntities

            await loadSectionOrderIfNeeded()
            await loadFilterSettingsIfNeeded()
            await loadEntityOrdersIfNeeded()

            // Subscribe to entity changes first - sections will be built when data arrives
            subscribeToEntitiesChanges()
            isLoading = false
        } catch {
            Current.Log.error("Failed to load entities for HomeViewModel: \(error.localizedDescription)")
        }
    }

    private func buildSectionsFromEntityStates() {
        do {
            let serverId = server.identifier.rawValue
            let areas = try AppArea.fetchAreas(for: serverId)
            let entityToAreaMap = createEntityToAreaMap(areas: areas)

            // Filter entities by allowed domains
            let allowedDomains = Set(EntityDisplayService.allowedDomains.map(\.rawValue))
            let filteredEntities = entityStates.values.filter { entity in
                allowedDomains.contains(entity.domain)
            }

            let roomGroups = groupEntitiesByArea(entities: Array(filteredEntities), entityToAreaMap: entityToAreaMap)
            groupedEntities = buildSortedRoomSections(from: roomGroups)
        } catch {
            Current.Log.error("Failed to build sections from entity states: \(error.localizedDescription)")
            errorMessage = "Failed to build sections: \(error.localizedDescription)"
        }
    }

    private func createEntityToAreaMap(areas: [AppArea]) -> [String: AppArea] {
        var entityToArea: [String: AppArea] = [:]
        for area in areas {
            for entityId in area.entities {
                entityToArea[entityId] = area
            }
        }
        return entityToArea
    }

    private func groupEntitiesByArea(
        entities: [HAEntity],
        entityToAreaMap: [String: AppArea]
    ) -> [String: (area: AppArea, entities: [HAEntity])] {
        var roomGroups: [String: (area: AppArea, entities: [HAEntity])] = [:]

        for entity in entities {
            guard let area = entityToAreaMap[entity.entityId] else {
                // Entities without an area are skipped
                continue
            }

            let key = area.id
            if roomGroups[key] == nil {
                roomGroups[key] = (area, [])
            }
            roomGroups[key]?.entities.append(entity)
        }

        return roomGroups
    }

    private func buildSortedRoomSections(
        from roomGroups: [String: (area: AppArea, entities: [HAEntity])]
    ) -> [RoomSection] {
        let sortedGroups = roomGroups.sorted { $0.value.area.name < $1.value.area.name }

        return sortedGroups.map { key, value in
            let filteredEntities = value.entities.filter { !hiddenEntityIds.contains($0.entityId) }
            let sortedEntities = sortEntitiesForRoom(filteredEntities, roomId: key)
            return RoomSection(
                id: key,
                name: value.area.name,
                entities: sortedEntities
            )
        }
    }

    /// Sort entities for a specific room using saved order
    private func sortEntitiesForRoom(_ entities: [HAEntity], roomId: String) -> [HAEntity] {
        guard let order = entityOrderByRoom[roomId], !order.isEmpty else {
            // No custom order, sort alphabetically by entity ID
            return entities.sorted { $0.entityId < $1.entityId }
        }

        let orderIndex = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return entities.sorted { a, b in
            let ia = orderIndex[a.entityId] ?? Int.max
            let ib = orderIndex[b.entityId] ?? Int.max
            return ia == ib ? a.entityId < b.entityId : ia < ib
        }
    }

    private func subscribeToEntitiesChanges() {
        let validAppEntityIds = Set(
            appEntities
                .filter { !$0.isHidden && !$0.isDisabled }
                .map(\.entityId)
        )

        let invalidRegistryEntityIds = Set(
            registryEntities
                .filter { $0.registry.entityCategory != nil }
                .map(\.entityId)
        )
        entityService.subscribeToEntitiesChanges(server: server) { [weak self] states in
            guard let self else { return }

            entityStates = states.filter { entityId, _ in
                validAppEntityIds.contains(entityId) &&
                    !invalidRegistryEntityIds.contains(entityId)
            }

            buildSectionsFromEntityStates()
        }
    }

    func filteredSections(sectionOrder: [String], selectedSectionIds: Set<String>) -> [RoomSection] {
        // Apply saved ordering
        let orderedSections: [RoomSection]
        if sectionOrder.isEmpty {
            orderedSections = groupedEntities
        } else {
            let orderIndex = Dictionary(uniqueKeysWithValues: sectionOrder.enumerated().map { ($1, $0) })
            orderedSections = groupedEntities.sorted { a, b in
                let ia = orderIndex[a.id] ?? Int.max
                let ib = orderIndex[b.id] ?? Int.max
                if ia == ib { return a.name < b.name }
                return ia < ib
            }
        }
        // If no sections are selected, show all
        guard !selectedSectionIds.isEmpty else {
            return orderedSections
        }
        // Otherwise, filter to only selected sections
        return orderedSections.filter { selectedSectionIds.contains($0.id) }
    }

    var orderedSectionsForMenu: [RoomSection] {
        // Use the same ordering logic as filteredSections, but show ALL sections (no filtering)
        if sectionOrder.isEmpty {
            return groupedEntities
        } else {
            let orderIndex = Dictionary(uniqueKeysWithValues: sectionOrder.enumerated().map { ($1, $0) })
            return groupedEntities.sorted { a, b in
                let ia = orderIndex[a.id] ?? Int.max
                let ib = orderIndex[b.id] ?? Int.max
                if ia == ib { return a.name < b.name }
                return ia < ib
            }
        }
    }

    func toggledSelection(
        for sectionId: String,
        current selected: Set<String>,
        allowMultipleSelection: Bool
    ) -> Set<String> {
        var updated = selected
        if allowMultipleSelection {
            if updated.contains(sectionId) {
                updated.remove(sectionId)
            } else {
                updated.insert(sectionId)
            }
        } else {
            if updated.contains(sectionId) {
                updated.removeAll()
            } else {
                updated = [sectionId]
            }
        }
        return updated
    }

    // MARK: - Section Order Persistence

    private var sectionOrderCacheKey: String {
        // Use a server-specific key; prefer a stable identifier if available
        "home.sections.order." + server.identifier.rawValue
    }

    private func loadSectionOrderIfNeeded() async {
        do {
            let order: [String] = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: sectionOrderCacheKey)
                    .done { (order: [String]) in
                        continuation.resume(returning: order)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            sectionOrder = order
        } catch {
            // If no cached order exists, use default (entity IDs)
            sectionOrder = groupedEntities.map(\.id)
        }
    }

    func saveSectionOrder() {
        Current.diskCache.set(sectionOrder, for: sectionOrderCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save sections order: \(error)")
            }
        }
    }

    // MARK: - Hidden Entities

    func hideEntity(_ entityId: String) {
        hiddenEntityIds.insert(entityId)
        EntityDisplayService.saveHiddenEntities(hiddenEntityIds, for: server)
        rebuildSections()
    }

    func unhideEntity(_ entityId: String) {
        hiddenEntityIds.remove(entityId)
        EntityDisplayService.saveHiddenEntities(hiddenEntityIds, for: server)
        // Rebuild sections to show the entity again
        rebuildSections()
    }

    func reloadAfterUnhide() async {
        // Reload hidden entities from cache (in case they were changed in RoomView)
        hiddenEntityIds = await EntityDisplayService.loadHiddenEntities(for: server)
        // Rebuild sections to reflect the changes
        rebuildSections()
    }

    private func rebuildSections() {
        // Rebuild sections based on current entity states
        buildSectionsFromEntityStates()
    }

    // MARK: - Filter Settings Persistence

    private var filterSettingsCacheKey: String {
        "home.filterSettings." + server.identifier.rawValue
    }

    private func loadFilterSettingsIfNeeded() async {
        do {
            let settings: FilterSettings = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: filterSettingsCacheKey)
                    .done { (settings: FilterSettings) in
                        continuation.resume(returning: settings)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            selectedSectionIds = settings.selectedSectionIds
            allowMultipleSelection = settings.allowMultipleSelection
        } catch {
            // No filter settings cached, use defaults
            selectedSectionIds = []
            allowMultipleSelection = false
        }
    }

    func saveFilterSettings() {
        let settings = FilterSettings(
            selectedSectionIds: selectedSectionIds,
            allowMultipleSelection: allowMultipleSelection
        )
        Current.diskCache.set(settings, for: filterSettingsCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save filter settings: \(error)")
            }
        }
    }

    struct FilterSettings: Codable {
        let selectedSectionIds: Set<String>
        let allowMultipleSelection: Bool
    }

    // MARK: - Entity Order Persistence (Per Room)

    private var entityOrderCacheKey: String {
        "home.entityOrders." + server.identifier.rawValue
    }

    private func loadEntityOrdersIfNeeded() async {
        do {
            let orders: [String: [String]] = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: entityOrderCacheKey)
                    .done { (orders: [String: [String]]) in
                        continuation.resume(returning: orders)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            entityOrderByRoom = orders
        } catch {
            // No cached orders, use empty dictionary
            entityOrderByRoom = [:]
        }
    }

    func saveEntityOrder(for roomId: String, order: [String]) {
        entityOrderByRoom[roomId] = order
        Current.diskCache.set(entityOrderByRoom, for: entityOrderCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save entity orders: \(error)")
            }
        }
        // Rebuild sections to reflect new order
        rebuildSections()
    }

    func getEntityOrder(for roomId: String) -> [String] {
        entityOrderByRoom[roomId] ?? []
    }
}
