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

    struct RoomSection: Identifiable, Equatable {
        let id: String
        let name: String
        let entities: [HAAppEntity]
    }

    private var entitiesSubscriptionToken: HACancellable?

    private var allowedDomains: [Domain] = [
        .light,
        .cover,
        .switch,
        .fan,
    ]

    init(server: Server) {
        self.server = server
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        // Load hidden entities and section order BEFORE building sections
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadHiddenEntitiesIfNeeded() }
            group.addTask { await self.loadSectionOrderIfNeeded() }
        }

        do {
            let sections = try await fetchAndGroupEntities()
            groupedEntities = sections
            isLoading = false
            subscribeToEntitiesChanges()
        } catch {
            Current.Log.error("Failed to load entities for HomeView: \(error.localizedDescription)")
            errorMessage = "Failed to load entities: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func fetchAndGroupEntities() async throws -> [RoomSection] {
        let serverId = server.identifier.rawValue
        let allEntities = try HAAppEntity.config() ?? []

        let entitiesWithCategories = try fetchEntitiesWithCategories(serverId: serverId)
        let serverEntities = filterEntities(
            allEntities,
            serverId: serverId,
            excludingCategories: entitiesWithCategories
        )
        let areas = try AppArea.fetchAreas(for: serverId)
        let entityToAreaMap = createEntityToAreaMap(areas: areas)
        let roomGroups = groupEntitiesByArea(entities: serverEntities, entityToAreaMap: entityToAreaMap)

        return buildSortedRoomSections(from: roomGroups)
    }

    private func fetchEntitiesWithCategories(serverId: String) throws -> Set<String> {
        do {
            let registryEntities = try Current.database().read { db in
                try AppEntityRegistryListForDisplay
                    .filter(
                        Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == serverId
                    )
                    .fetchAll(db)
            }
            // Return entity IDs that have a non-nil category (config/diagnostic entities)
            return Set(registryEntities.filter { $0.registry.entityCategory != nil }.map(\.entityId))
        } catch {
            Current.Log.error("Failed to fetch entity registry for filtering: \(error.localizedDescription)")
            return []
        }
    }

    private func filterEntities(
        _ entities: [HAAppEntity],
        serverId: String,
        excludingCategories categorizedEntities: Set<String>
    ) -> [HAAppEntity] {
        entities.filter {
            $0.serverId == serverId &&
                allowedDomains.map(\.rawValue).contains($0.domain) &&
                !categorizedEntities.contains($0.entityId)
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
        entities: [HAAppEntity],
        entityToAreaMap: [String: AppArea]
    ) -> [String: (area: AppArea, entities: [HAAppEntity])] {
        var roomGroups: [String: (area: AppArea, entities: [HAAppEntity])] = [:]

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
        from roomGroups: [String: (area: AppArea, entities: [HAAppEntity])]
    ) -> [RoomSection] {
        let sortedGroups = roomGroups.sorted { $0.value.area.name < $1.value.area.name }

        return sortedGroups.map { key, value in
            let filteredEntities = value.entities.filter { !hiddenEntityIds.contains($0.entityId) }
            return RoomSection(
                id: key,
                name: value.area.name,
                entities: filteredEntities.sorted { $0.name < $1.name }
            )
        }
    }

    private func subscribeToEntitiesChanges() {
        entitiesSubscriptionToken?.cancel()

        var filter: [String: Any] = [:]
        if server.info.version > .canSubscribeEntitiesChangesWithFilter {
            filter = [
                "include": [
                    "domains": allowedDomains.map(\.rawValue),
                ],
            ]
        }

        // Guarantee fresh data
        Current.api(for: server)?.connection.disconnect()
        entitiesSubscriptionToken = Current.api(for: server)?.connection.caches.states(filter)
            .subscribe { [weak self] _, states in
                Task { @MainActor [weak self] in
                    self?.entityStates = states.all.reduce(into: [:]) { $0[$1.entityId] = $1 }
                }
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

    private var hiddenEntitiesCacheKey: String {
        "home.hiddenEntities." + server.identifier.rawValue
    }

    private func loadHiddenEntitiesIfNeeded() async {
        do {
            let hidden: Set<String> = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: hiddenEntitiesCacheKey)
                    .done { (hidden: Set<String>) in
                        continuation.resume(returning: hidden)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            hiddenEntityIds = hidden
        } catch {
            // No hidden entities cached, start with empty set
            hiddenEntityIds = []
        }
    }

    func hideEntity(_ entityId: String) {
        hiddenEntityIds.insert(entityId)
        saveHiddenEntities()
        rebuildSections()
    }

    func unhideEntity(_ entityId: String) {
        hiddenEntityIds.remove(entityId)
        saveHiddenEntities()
        // Rebuild sections to show the entity again
        rebuildSections()
    }

    private func rebuildSections() {
        // Rebuild sections to remove the hidden entity
        Task {
            do {
                let sections = try await fetchAndGroupEntities()
                DispatchQueue.main.async { [weak self] in
                    self?.groupedEntities = sections
                }
            } catch {
                Current.Log.error("Failed to reload entities after hiding: \(error.localizedDescription)")
            }
        }
    }

    private func saveHiddenEntities() {
        Current.diskCache.set(hiddenEntityIds, for: hiddenEntitiesCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save hidden entities: \(error)")
            }
        }
    }
}
