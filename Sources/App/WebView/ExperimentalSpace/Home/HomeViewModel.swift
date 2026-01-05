import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class HomeViewModel: ObservableObject {
    struct RoomSection: Identifiable, Equatable {
        let id: String
        let name: String
        let entityIds: [String]
    }

    var groupedEntities: [RoomSection] = []
    var isLoading = false
    var errorMessage: String?
    var server: Server
    var entityStates: [String: HAEntity] = [:]
    var configuration: HomeViewConfiguration {
        didSet {
            saveCachedData()
        }
    }

    private var appEntities: [HAAppEntity]? {
        didSet {
            guard !(appEntities?.isEmpty ?? true) else { return }
            buildSections()
        }
    }

    private var registryEntities: [AppEntityRegistryListForDisplay]? {
        didSet {
            guard !(registryEntities?.isEmpty ?? true) else { return }
            buildSections()
        }
    }

    private let entityService = EntityDisplayService()
    private var configObservation: AnyDatabaseCancellable?
    private var appEntitiesObservation: AnyDatabaseCancellable?
    private var registryEntitiesObservation: AnyDatabaseCancellable?
    private var isSubscriptionActive = false
    private var saveTask: Task<Void, Never>?

    init(server: Server) {
        self.server = server
        self.configuration = HomeViewConfiguration(id: server.identifier.rawValue)
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        // Subscribe to entity changes - sections will be built when data arrives
        startSubscriptions()
        isLoading = false
    }

    // MARK: - Lifecycle Management

    /// Call this when the app enters foreground
    func handleAppDidBecomeActive() {
        Current.Log.info("HomeViewModel: App became active, starting subscriptions")
        startSubscriptions()
    }

    /// Call this when the app enters background
    func handleAppDidEnterBackground() {
        Current.Log.info("HomeViewModel: App entered background, stopping subscriptions")
        stopSubscriptions()
    }

    private func startSubscriptions() {
        guard !isSubscriptionActive else {
            Current.Log.info("HomeViewModel: Subscriptions already active, skipping")
            return
        }
        observeConfigChanges()
        observeAppEntitiesChanges()
        observeRegistryEntitiesChanges()
        subscribeToEntitiesChanges()
        isSubscriptionActive = true
    }

    private func stopSubscriptions() {
        guard isSubscriptionActive else {
            Current.Log.info("HomeViewModel: Subscriptions already stopped, skipping")
            return
        }

        entityService.cancelSubscription()
        configObservation?.cancel()
        appEntitiesObservation?.cancel()
        registryEntitiesObservation?.cancel()
        isSubscriptionActive = false
    }

    private func observeConfigChanges() {
        // Don't cancel here as it will be managed by lifecycle methods
        let serverId = server.identifier.rawValue
        let observation = ValueObservation.tracking { db in
            try HomeViewConfiguration.fetchOne(db, key: serverId)
        }
        configObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("Home view config observation failed with error: \(error)")
            },
            onChange: { [weak self] config in
                guard let self else { return }
                configuration = config ?? .init(id: server.identifier.rawValue)
            }
        )
    }

    private func observeAppEntitiesChanges() {
        let serverId = server.identifier.rawValue
        let observation = ValueObservation.tracking { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.hiddenBy.rawValue) == nil)
                .filter(Column(DatabaseTables.AppEntity.disabledBy.rawValue) == nil)
                .filter(Column("serverId") == serverId)
                .fetchAll(db)
        }
        appEntitiesObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("App entities observation failed with error: \(error)")
            },
            onChange: { [weak self] entities in
                guard let self else { return }
                appEntities = entities
            }
        )
    }

    private func observeRegistryEntitiesChanges() {
        let serverId = server.identifier.rawValue
        let observation = ValueObservation.tracking { db in
            try AppEntityRegistryListForDisplay
                .filter(Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        registryEntitiesObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("Registry entities observation failed with error: \(error)")
            },
            onChange: { [weak self] entities in
                guard let self else { return }
                registryEntities = entities
            }
        )
    }

    private func buildSections() {
        guard let appEntities, let registryEntities else {
            // Not ready to render UI yet
            return
        }
        let serverId = server.identifier.rawValue
        // Filter by valid app entities (not hidden/disabled)
        let validAppEntities = appEntities.filter { !$0.isHidden && !$0.isDisabled }

        // Filter by registry entities (exclude those with entity category)
        let invalidRegistryEntityIds = Set(
            registryEntities
                .filter { $0.registry.entityCategory != nil }
                .map(\.entityId)
        )

        // Filter out entities that have an entity category
        let filteredAppEntities = validAppEntities.filter { !invalidRegistryEntityIds.contains($0.entityId) }

        do {
            let areas = try AppArea.fetchAreas(for: serverId)
            let entityToAreaMap = createEntityToAreaMap(areas: areas)
            let roomGroups = groupEntitiesByArea(
                entityIds: filteredAppEntities.map(\.entityId),
                entityToAreaMap: entityToAreaMap
            )
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
        entityIds: [String],
        entityToAreaMap: [String: AppArea]
    ) -> [String: (area: AppArea, entityIds: [String])] {
        var roomGroups: [String: (area: AppArea, entityIds: [String])] = [:]

        for entityId in entityIds {
            guard let area = entityToAreaMap[entityId] else {
                // Entities without an area are skipped
                continue
            }

            let key = area.id
            if roomGroups[key] == nil {
                roomGroups[key] = (area, [])
            }
            roomGroups[key]?.entityIds.append(entityId)
        }

        return roomGroups
    }

    private func buildSortedRoomSections(
        from roomGroups: [String: (area: AppArea, entityIds: [String])]
    ) -> [RoomSection] {
        let sortedGroups = roomGroups.sorted { $0.value.area.name < $1.value.area.name }

        return sortedGroups.map { key, value in
            let filteredEntityIds = value.entityIds.filter { !configuration.hiddenEntityIds.contains($0) }
            let sortedEntityIds = sortEntityIdsForRoom(filteredEntityIds, roomId: key)
            return RoomSection(
                id: key,
                name: value.area.name,
                entityIds: sortedEntityIds
            )
        }
    }

    /// Sort entity IDs for a specific room using saved order
    private func sortEntityIdsForRoom(_ entityIds: [String], roomId: String) -> [String] {
        guard let order = configuration.entityOrderByRoom[roomId], !order.isEmpty else {
            // No custom order, sort alphabetically by entity ID
            return entityIds.sorted()
        }

        let orderIndex = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return entityIds.sorted { a, b in
            let ia = orderIndex[a] ?? Int.max
            let ib = orderIndex[b] ?? Int.max
            return ia == ib ? a < b : ia < ib
        }
    }

    private func subscribeToEntitiesChanges() {
        entityService.subscribeToEntitiesChanges(server: server) { [weak self] states in
            guard let self else { return }
            entityStates = states
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

    /// Save all current state to database with debouncing
    private func saveCachedData() {
        // Cancel any pending save task
        saveTask?.cancel()

        // Schedule a new save after 1 second
        saveTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
                try configuration.save()
                buildSections()
            } catch is CancellationError {
                // Task was cancelled, do nothing
            } catch {
                Current.Log.error("Failed to save Home view configuration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Hidden Entities

    func hideEntity(_ entityId: String) {
        configuration.hiddenEntityIds.insert(entityId)
    }

    func unhideEntity(_ entityId: String) {
        configuration.hiddenEntityIds.remove(entityId)
    }

    // MARK: - Entity Order (Per Room)

    func saveEntityOrder(for roomId: String, order: [String]) {
        configuration.entityOrderByRoom[roomId] = order
    }

    func getEntityOrder(for roomId: String) -> [String] {
        configuration.entityOrderByRoom[roomId] ?? []
    }
}
