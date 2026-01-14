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
        let entityIds: Set<String>
    }

    // MARK: - Constants

    static let usagePredictionSectionId = "usage-prediction-common-control"

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

    var appEntities: [HAAppEntity]?
    var registryEntities: [AppEntityRegistryListForDisplay]?
    var usagePredictionCommonControl: HAUsagePredictionCommonControl? {
        didSet {
            buildRoomsIfNeeded()
        }
    }

    var cachedUserName: String = ""
    private var lastUsagePredictionLoadTime: Date?
    private let usagePredictionLoadInterval: TimeInterval = 120 // 2 minutes

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

    /// Returns the Usage Prediction Common Control section if available
    var usagePredictionSection: RoomSection? {
        guard let entities = usagePredictionCommonControl?.entities, !entities.isEmpty else {
            return nil
        }
        return RoomSection(
            id: Self.usagePredictionSectionId,
            name: L10n.HomeView.CommonControls.title(cachedUserName),
            entityIds: Set(entities)
        )
    }

    private var areas: [AppArea]? {
        didSet {
            buildRoomsIfNeeded()
        }
    }

    private let entityService = EntityDisplayService()
    private var configObservation: AnyDatabaseCancellable?
    private var appEntitiesObservation: AnyDatabaseCancellable?
    private var registryEntitiesObservation: AnyDatabaseCancellable?
    private var areasObservation: AnyDatabaseCancellable?
    private var isSubscriptionActive = false
    private var saveTask: Task<Void, Never>?

    init(server: Server) {
        self.server = server
        self.configuration = HomeViewConfiguration(id: server.identifier.rawValue)
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        // Cache the username from the current user
        await cacheUserName()

        // Load usage prediction common control data
        await loadUsagePredictionCommonControl()

        // Subscribe to entity changes - sections will be built when data arrives
        startSubscriptions()
        isLoading = false
    }

    private func cacheUserName() async {
        Current.api(for: server)?.connection.caches.user.once { [weak self] user in
            guard let self else { return }
            cachedUserName = user.name ?? ""
            Current.Log.verbose("Cached user name: \(String(describing: user.name))")
        }
    }

    private func loadUsagePredictionCommonControl() async {
        // Check if we should load based on time interval
        let shouldLoad = shouldLoadUsagePrediction()
        guard shouldLoad else {
            Current.Log.verbose("Skipping usage prediction load - within 2 minute interval")
            return
        }

        Current.api(for: server)?.connection.send(.usagePredictionCommonControl()) { result in
            switch result {
            case let .success(usagePredictionCommonControl):
                self.usagePredictionCommonControl = usagePredictionCommonControl
                self.lastUsagePredictionLoadTime = Date()
            case let .failure(error):
                Current.Log.error("Failed to load usage prediction common control: \(error.localizedDescription)")
            }
        }
    }

    private func shouldLoadUsagePrediction() -> Bool {
        guard let lastLoadTime = lastUsagePredictionLoadTime else {
            // Never loaded before, should load
            return true
        }

        let timeSinceLastLoad = Date().timeIntervalSince(lastLoadTime)
        return timeSinceLastLoad >= usagePredictionLoadInterval
    }

    // MARK: - Lifecycle Management

    /// Call this when the app enters foreground
    func handleAppDidBecomeActive() {
        Current.Log.info("HomeViewModel: App became active, starting subscriptions")
        Task {
            await loadUsagePredictionCommonControl()
        }
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
        observeAreasChanges()
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
        areasObservation?.cancel()
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

    private func observeAreasChanges() {
        let serverId = server.identifier.rawValue
        let observation = ValueObservation.tracking { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .order(Column(DatabaseTables.AppArea.name.rawValue))
                .fetchAll(db)
        }
        areasObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("Areas observation failed with error: \(error)")
            },
            onChange: { [weak self] areas in
                guard let self else { return }
                self.areas = areas
            }
        )
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

    private func buildRoomsIfNeeded() {
        guard let areas else { return }

        groupedEntities = areas.map {
            RoomSection(id: $0.id, name: $0.name, entityIds: $0.entities)
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
