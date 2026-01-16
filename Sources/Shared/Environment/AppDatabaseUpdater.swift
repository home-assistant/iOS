import Foundation
import GRDB
import HAKit
import UIKit

/// AppDatabaseUpdater coordinates fetching data from servers and persisting it into the local database.
/// It ensures only one update per server runs at a time (different servers can update concurrently),
/// applies per-server throttling with backoff, and performs careful cancellation and batched DB writes.
public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update(server: Server) async
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    enum UpdateError: Error {
        case noAPI
    }

    // Actor for thread-safe task management
    private actor TaskCoordinator {
        private var currentUpdateTasks: [String: Task<Void, Never>] = [:]

        func getTask(for serverId: String) -> Task<Void, Never>? {
            currentUpdateTasks[serverId]
        }

        func setTask(_ task: Task<Void, Never>, for serverId: String) {
            currentUpdateTasks[serverId] = task
        }

        func removeTask(for serverId: String) {
            currentUpdateTasks.removeValue(forKey: serverId)
        }

        func cancelAllTasks() {
            for (_, task) in currentUpdateTasks {
                task.cancel()
            }
            currentUpdateTasks.removeAll()
        }
    }

    private let taskCoordinator = TaskCoordinator()

    // Simple adaptive throttling/backoff
    // - Tracks consecutive failures per server to increase delay between attempts.
    // - Tracks per-server last successful (or attempted) update times to avoid over-fetching.
    private var consecutiveFailuresByServer: [String: Int] = [:]
    private var perServerLastUpdate: [String: Date] = [:]
    // Base throttle applied to all servers; backoff is added on top of this.
    private let baseThrottleSeconds: TimeInterval = 120

    static var shared = AppDatabaseUpdater()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func enterBackground() {
        stop()
    }

    /// Cancels any in-flight work and clears transient state.
    /// Called when app enters background or when we need to abort updates early.
    func stop() {
        Task {
            await taskCoordinator.cancelAllTasks()
        }

        // Reset backoff tracking to free memory and avoid stale penalties
        consecutiveFailuresByServer.removeAll()
    }

    /// Starts an update for a specific server.
    /// - Parameter server: The specific server to update.
    /// - Ensures only one update per server runs at a time. Different servers can update concurrently.
    /// - Applies per-server throttling with exponential backoff on failures.
    func update(server: Server) async {
        let serverId = server.identifier.rawValue

        // Check if an update for this specific server is already running
        if let existingTask = await taskCoordinator.getTask(for: serverId) {
            Current.Log.verbose("Update already in progress for server \(server.info.name), awaiting existing task")
            await existingTask.value
            return
        }

        Current.Log.verbose("Updating database for server \(server.info.name)")

        // Show toast indicating update has started
        await showUpdateToast(for: server)

        // Launch the server-specific update task
        let updateTask = Task { [weak self] in
            guard let self else { return }
            defer {
                // Hide toast and clean up task reference when complete
                Task {
                    await self.hideUpdateToast(for: server)
                    await self.taskCoordinator.removeTask(for: serverId)
                }
            }

            await performSingleServerUpdate(server: server)
        }

        // Store the task for this server
        await taskCoordinator.setTask(updateTask, for: serverId)

        await updateTask.value
    }

    /// Determines if a specific server should be updated based on connection and throttle rules.
    private func shouldUpdateServer(_ server: Server) -> Bool {
        guard server.info.connection.activeURL() != nil else { return false }
        if Task.isCancelled { return false }

        // Per-server throttle with exponential backoff
        if let last = perServerLastUpdate[server.identifier.rawValue] {
            let failures = consecutiveFailuresByServer[server.identifier.rawValue] ?? 0
            let backoff = min(pow(2.0, Double(failures)) * 10.0, 300.0) // 10s, 20s, 40s... up to 5m
            let threshold = -(baseThrottleSeconds + backoff)
            return last.timeIntervalSinceNow <= threshold
        }
        return true
    }

    /// Performs an update for a single specific server.
    private func performSingleServerUpdate(server: Server) async {
        guard !Task.isCancelled else { return }
        guard shouldUpdateServer(server) else {
            Current.Log.verbose("Skipping update for server \(server.info.name) - throttled")
            return
        }

        let success = await safeUpdateServer(server: server)
        updateServerTracking(serverId: server.identifier.rawValue, success: success)
    }

    /// Updates per-server tracking after an update attempt completes.
    private func updateServerTracking(serverId: String, success: Bool) {
        if success {
            perServerLastUpdate[serverId] = Date()
            consecutiveFailuresByServer[serverId] = 0
        } else {
            consecutiveFailuresByServer[serverId, default: 0] += 1
        }
    }

    /// Wraps a per-server update with cancellation checks and returns whether it succeeded.
    /// This allows the scheduler to apply backoff on failures and update last-run times on success.
    private func safeUpdateServer(server: Server) async -> Bool {
        if Task.isCancelled { return false }
        await updateServer(server: server)
        if Task.isCancelled { return false }
        return true
    }

    /// Runs the full update pipeline for a single server in sequence.
    /// Each phase checks for cancellation to bail out quickly when needed.
    private func updateServer(server: Server) async {
        guard !Task.isCancelled else { return }
        // 1) Entities (fetch_states)
        await updateEntitiesDatabase(server: server)
        if Task.isCancelled { return }
        // 2) Entities registry list for display
        await updateEntitiesRegistryListForDisplay(server: server)
        if Task.isCancelled { return }
        // 3) Entities registry
        await updateEntitiesRegistry(server: server)
        if Task.isCancelled { return }
        // 4) Devices registry
        await updateDevicesRegistry(server: server)
        if Task.isCancelled { return }
        // 5) Areas with their entities
        // IMPORTANT: This must be executed after entities and device registry
        // since we rely on that data to map entities to areas
        await updateAreasDatabase(server: server)
    }

    /// Fetches entities' states from the API and forwards results to persistence.
    /// Early-exits on cancellation and resumes continuations to avoid leaks.
    private func updateEntitiesDatabase(server: Server) async {
        guard !Task.isCancelled else { return }
        await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<Void, Never>) in
            guard self != nil else {
                continuation.resume()
                return
            }
            guard let api = Current.api(for: server) else {
                Current.Log.error("No API available for server \(server.info.name)")
                continuation.resume()
                return
            }
            // If cancelled after acquiring API, resume the continuation to avoid hanging.
            if Task.isCancelled {
                continuation.resume()
                return
            }
            api.connection.send(HATypedRequest<[HAEntity]>.fetchStates()) { result in
                switch result {
                case let .success(entities):
                    Current.appEntitiesModel().updateModel(Set(entities), server: server)
                case let .failure(error):
                    Current.Log.error("Failed to fetch states: \(error)")
                    Current.clientEventStore.addEvent(.init(
                        text: "Failed to fetch states on server \(server.info.name)",
                        type: .networkRequest,
                        payload: [
                            "error": error.localizedDescription,
                        ]
                    ))
                }
                continuation.resume()
            }
        }
    }

    /// Fetches entity registry from the API and forwards results to persistence.
    /// Early-exits on cancellation and resumes continuations to avoid leaks.
    private func updateEntitiesRegistry(server: Server) async {
        guard !Task.isCancelled else { return }
        let registryEntries: [EntityRegistryEntry]? =
            await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<
                [EntityRegistryEntry]?,
                Never
            >) in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let api = Current.api(for: server) else {
                    Current.Log.error("No API available for server \(server.info.name)")
                    continuation.resume(returning: nil)
                    return
                }
                // If cancelled after acquiring API, resume the continuation to avoid hanging.
                if Task.isCancelled {
                    continuation.resume(returning: nil)
                    return
                }
                api.connection.send(.configEntityRegistryList()) { result in
                    switch result {
                    case let .success(entries):
                        Current.Log.verbose("Successfully fetched entity registry for server \(server.info.name)")
                        continuation.resume(returning: entries)
                    case let .failure(error):
                        Current.Log.error("Failed to fetch entity registry: \(error)")
                        Current.clientEventStore.addEvent(.init(
                            text: "Failed to fetch entity registry on server \(server.info.name)",
                            type: .networkRequest,
                            payload: [
                                "error": error.localizedDescription,
                            ]
                        ))
                        continuation.resume(returning: nil)
                    }
                }
            }

        if let registryEntries {
            await saveEntityRegistry(registryEntries, serverId: server.identifier.rawValue)
        }
    }

    /// Fetches device registry from the API and forwards results to persistence.
    /// Early-exits on cancellation and resumes continuations to avoid leaks.
    private func updateDevicesRegistry(server: Server) async {
        guard !Task.isCancelled else { return }
        let registryEntries: [DeviceRegistryEntry]? =
            await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<
                [DeviceRegistryEntry]?,
                Never
            >) in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let api = Current.api(for: server) else {
                    Current.Log.error("No API available for server \(server.info.name)")
                    continuation.resume(returning: nil)
                    return
                }
                // If cancelled after acquiring API, resume the continuation to avoid hanging.
                if Task.isCancelled {
                    continuation.resume(returning: nil)
                    return
                }
                api.connection.send(.configDeviceRegistryList()) { result in
                    switch result {
                    case let .success(entries):
                        Current.Log.verbose("Successfully fetched device registry for server \(server.info.name)")
                        continuation.resume(returning: entries)
                    case let .failure(error):
                        Current.Log.error("Failed to fetch device registry: \(error)")
                        Current.clientEventStore.addEvent(.init(
                            text: "Failed to fetch device registry on server \(server.info.name)",
                            type: .networkRequest,
                            payload: [
                                "error": error.localizedDescription,
                            ]
                        ))
                        continuation.resume(returning: nil)
                    }
                }
            }

        if let registryEntries {
            await saveDeviceRegistry(registryEntries, serverId: server.identifier.rawValue)
        }
    }

    /// Fetches entity registry list-for-display from the API and forwards results to persistence.
    /// Early-exits on cancellation and resumes continuations to avoid leaks.
    private func updateEntitiesRegistryListForDisplay(server: Server) async {
        guard !Task.isCancelled else { return }
        let response: EntityRegistryListForDisplay? =
            await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<
                EntityRegistryListForDisplay?,
                Never
            >) in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let api = Current.api(for: server) else {
                    Current.Log.error("No API available for server \(server.info.name)")
                    continuation.resume(returning: nil)
                    return
                }
                // If cancelled after acquiring API, resume the continuation to avoid hanging.
                if Task.isCancelled {
                    continuation.resume(returning: nil)
                    return
                }
                api.connection.send(
                    HATypedRequest<EntityRegistryListForDisplay>.configEntityRegistryListForDisplay()
                ) { result in
                    switch result {
                    case let .success(response):
                        continuation.resume(returning: response)
                    case let .failure(error):
                        Current.Log.error("Failed to fetch EntityRegistryListForDisplay: \(error)")
                        Current.clientEventStore.addEvent(.init(
                            text: "Failed to fetch EntityRegistryListForDisplay on server \(server.info.name)",
                            type: .networkRequest,
                            payload: [
                                "error": error.localizedDescription,
                            ]
                        ))
                        continuation.resume(returning: nil)
                    }
                }
            }

        if let response {
            await saveEntityRegistryListForDisplay(response, serverId: server.identifier.rawValue)
        }
    }

    private func updateAreasDatabase(server: Server) async {
        let areasAndEntities = await Current.areasProvider().fetchAreasAndItsEntities(for: server)

        guard let areas = Current.areasProvider().areas[server.identifier.rawValue] else {
            Current.Log.verbose("No areas found for server \(server.info.name)")
            return
        }

        await saveAreasToDatabase(
            areas: areas,
            areasAndEntities: areasAndEntities,
            serverId: server.identifier.rawValue
        )
    }

    /// Persists areas and their entity relationships for a server.
    /// Uses a single asyncWrite transaction for batching, replaces existing rows, and deletes stale ones.
    /// For simplicity and speed, we upsert via `save(onConflict: .replace)`; deeper diffing can be added if needed.
    private func saveAreasToDatabase(
        areas: [HAAreasRegistryResponse],
        areasAndEntities: [String: Set<String>],
        serverId: String
    ) async {
        // Check for cancellation before starting database work
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping areas database save - task cancelled")
            return
        }

        let appAreas = areas.map { area in
            AppArea(
                from: area,
                serverId: serverId,
                entities: areasAndEntities[area.areaId]
            )
        }

        // Nothing to persist; keep going (delete pass below might still remove stale rows).
        if appAreas.isEmpty {
            Current.Log.verbose("No areas to save for server \(serverId)")
        }

        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard self != nil else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                Current.database().asyncWrite { db in
                    let existingAreaIds = try AppArea
                        .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                        .fetchAll(db).map(\.id)

                    // Insert or update new areas
                    for area in appAreas {
                        try area.save(db, onConflict: .replace)
                    }

                    // Delete areas that no longer exist
                    let newAreaIds = areas.map { "\(serverId)-\($0.areaId)" }
                    let areaIdsToDelete = existingAreaIds.filter { !newAreaIds.contains($0) }

                    if !areaIdsToDelete.isEmpty {
                        try AppArea
                            .filter(areaIdsToDelete.contains(Column(DatabaseTables.AppArea.id.rawValue)))
                            .deleteAll(db)
                    }
                } completion: { _, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            Current.Log.verbose("Successfully saved \(appAreas.count) areas for server \(serverId)")
        } catch is CancellationError {
            Current.Log.verbose("Areas database save cancelled for server \(serverId)")
        } catch {
            Current.Log.error("Failed to save areas in database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save areas in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
            assertionFailure("Failed to save areas in database: \(error)")
        }
    }

    /// Persists the entity registry list-for-display for a server with batched writes and stale deletions.
    /// Builds the payload with a streaming loop to reduce intermediate allocations vs filter+map.
    private func saveEntityRegistryListForDisplay(_ response: EntityRegistryListForDisplay, serverId: String) async {
        // Check for cancellation before starting database work
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping EntityRegistryListForDisplay database save - task cancelled")
            return
        }

        var entitiesListForDisplay: [AppEntityRegistryListForDisplay] = []
        entitiesListForDisplay.reserveCapacity(response.entities.count)
        for registry in response.entities {
            if registry.decimalPlaces != nil || registry.entityCategory != nil {
                entitiesListForDisplay.append(
                    AppEntityRegistryListForDisplay(
                        id: ServerEntity.uniqueId(serverId: serverId, entityId: registry.entityId),
                        serverId: serverId,
                        entityId: registry.entityId,
                        registry: registry
                    )
                )
            }
        }
        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard self != nil else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                // Note: we batch entities into memory before this write. This is a trade-off for simpler, atomic
                // updates;
                // if memory usage becomes an issue for very large datasets, consider a streaming or chunked approach.
                Current.database().asyncWrite { db in
                    // Get existing IDs for this server
                    let existingIds = try AppEntityRegistryListForDisplay
                        .filter(Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == serverId)
                        .fetchAll(db)
                        .map(\.id)

                    // Insert or update new records
                    for record in entitiesListForDisplay {
                        try record.save(db, onConflict: .replace)
                    }

                    // Delete records that no longer exist
                    let newIds = entitiesListForDisplay.map(\.id)
                    let idsToDelete = existingIds.filter { !newIds.contains($0) }

                    if !idsToDelete.isEmpty {
                        try AppEntityRegistryListForDisplay
                            .deleteAll(db, keys: idsToDelete)
                    }
                } completion: { _, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch is CancellationError {
            Current.Log.verbose("EntityRegistryListForDisplay database save cancelled for server \(serverId)")
        } catch {
            Current.Log
                .error("Failed to save EntityRegistryListForDisplay in database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save EntityRegistryListForDisplay in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
            assertionFailure("Failed to save EntityRegistryListForDisplay in database: \(error)")
        }
    }

    /// Persists the entity registry for a server using a single transaction and differential deletes.
    private func saveEntityRegistry(_ registryEntries: [EntityRegistryEntry], serverId: String) async {
        // If cancelled before touching the DB, bail out early to avoid unnecessary work.
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping entity registry database save - task cancelled")
            return
        }

        let appEntityRegistries = registryEntries.map { entry in
            AppEntityRegistry(serverId: serverId, registry: entry)
        }

        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard self != nil else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                Current.database().asyncWrite { db in
                    // Get existing unique IDs for this server
                    let existingIds = try AppEntityRegistry
                        .filter(Column(DatabaseTables.EntityRegistry.serverId.rawValue) == serverId)
                        .fetchAll(db)
                        .map(\.id)

                    // Insert or update new registry entries
                    for registry in appEntityRegistries {
                        try registry.save(db, onConflict: .replace)
                    }

                    // Delete registry entries that no longer exist
                    let newIds = appEntityRegistries.map(\.id)
                    let idsToDelete = existingIds.filter { !newIds.contains($0) }

                    if !idsToDelete.isEmpty {
                        try AppEntityRegistry
                            .deleteAll(db, keys: idsToDelete)
                    }
                } completion: { _, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            Current.Log
                .verbose(
                    "Successfully saved \(appEntityRegistries.count) entity registry entries for server \(serverId)"
                )
        } catch is CancellationError {
            Current.Log.verbose("Entity registry database save cancelled for server \(serverId)")
        } catch {
            Current.Log.error("Failed to save entity registry in database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save entity registry in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
            assertionFailure("Failed to save entity registry in database: \(error)")
        }
    }

    /// Persists the device registry for a server using a single transaction and differential deletes.
    private func saveDeviceRegistry(_ registryEntries: [DeviceRegistryEntry], serverId: String) async {
        // If cancelled before touching the DB, bail out early to avoid unnecessary work.
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping device registry database save - task cancelled")
            return
        }

        let appDeviceRegistries = registryEntries.map { entry in
            AppDeviceRegistry(serverId: serverId, registry: entry)
        }

        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard self != nil else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                Current.database().asyncWrite { db in
                    // Get existing device IDs for this server
                    let existingIds = try AppDeviceRegistry
                        .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                        .fetchAll(db)
                        .map(\.id)

                    // Insert or update new registry entries
                    for registry in appDeviceRegistries {
                        try registry.save(db, onConflict: .replace)
                    }

                    // Delete registry entries that no longer exist
                    let newIds = appDeviceRegistries.map(\.id)
                    let idsToDelete = existingIds.filter { !newIds.contains($0) }

                    if !idsToDelete.isEmpty {
                        try AppDeviceRegistry
                            .deleteAll(db, keys: idsToDelete)
                    }
                } completion: { _, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            Current.Log
                .verbose(
                    "Successfully saved \(appDeviceRegistries.count) device registry entries for server \(serverId)"
                )
        } catch is CancellationError {
            Current.Log.verbose("Device registry database save cancelled for server \(serverId)")
        } catch {
            Current.Log.error("Failed to save device registry in database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save device registry in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
            assertionFailure("Failed to save device registry in database: \(error)")
        }
    }

    // MARK: - Toast Management

    /// Shows a toast notification indicating a server update is in progress.
    @MainActor
    private func showUpdateToast(for server: Server) {
        if #available(iOS 18, *) {
            let toastId = "server-update-\(server.identifier.rawValue)"
            ToastManager.shared.show(
                id: toastId,
                symbol: "arrow.triangle.2.circlepath.circle.fill",
                symbolForegroundStyle: (.white, .blue),
                title: "Updating \(server.info.name)",
                message: "Syncing server data..."
            )
        }
    }

    /// Hides the toast notification for a completed server update.
    @MainActor
    private func hideUpdateToast(for server: Server) {
        if #available(iOS 18, *) {
            let toastId = "server-update-\(server.identifier.rawValue)"
            ToastManager.shared.hide(id: toastId)
        }
    }
}
