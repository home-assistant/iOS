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
    var configuration: HomeViewConfiguration

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
        self.configuration = HomeViewConfiguration(id: server.identifier.rawValue)
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        do {
            configuration = try HomeViewConfiguration.configuration(for: server.identifier.rawValue) ??
                HomeViewConfiguration(id: server.identifier.rawValue)
            // Does not include disabled and hidden entities, it will be used to filter HAEntity
            appEntities = try HAAppEntity.config().filter({ $0.serverId == server.identifier.rawValue })
            registryEntities = try AppEntityRegistryListForDisplay.config(serverId: server.identifier.rawValue)
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
            let filteredEntities = value.entities.filter { !configuration.hiddenEntityIds.contains($0.entityId) }
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
        guard let order = configuration.entityOrderByRoom[roomId], !order.isEmpty else {
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

    func filteredSections(sectionOrder: [String], visibleSectionIds: Set<String>) -> [RoomSection] {
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
        guard !visibleSectionIds.isEmpty else {
            return orderedSections
        }
        // Otherwise, filter to only selected sections
        return orderedSections.filter { visibleSectionIds.contains($0.id) }
    }

    var orderedSectionsForMenu: [RoomSection] {
        // Use the same ordering logic as filteredSections, but show ALL sections (no filtering)
        if configuration.sectionOrder.isEmpty {
            return groupedEntities
        } else {
            let orderIndex = Dictionary(uniqueKeysWithValues: configuration.sectionOrder.enumerated().map { ($1, $0) })
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

    /// Save all current state to database
    private func saveCachedData() {
        do {
            try configuration.save()
        } catch {
            Current.Log.error("Failed to save Home view configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Section Order

    func saveSectionOrder() {
        saveCachedData()
    }

    // MARK: - Filter Settings

    func saveFilterSettings() {
        saveCachedData()
    }

    // MARK: - Hidden Entities

    func hideEntity(_ entityId: String) {
        configuration.hiddenEntityIds.insert(entityId)
        saveCachedData()
        rebuildSections()
    }

    func unhideEntity(_ entityId: String) {
        configuration.hiddenEntityIds.remove(entityId)
        saveCachedData()
        rebuildSections()
    }

    private func rebuildSections() {
        // Rebuild sections based on current entity states
        buildSectionsFromEntityStates()
    }

    // MARK: - Entity Order (Per Room)

    func saveEntityOrder(for roomId: String, order: [String]) {
        configuration.entityOrderByRoom[roomId] = order
        saveCachedData()
        rebuildSections()
    }

    func getEntityOrder(for roomId: String) -> [String] {
        configuration.entityOrderByRoom[roomId] ?? []
    }
}
