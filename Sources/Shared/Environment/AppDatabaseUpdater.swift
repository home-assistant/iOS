import Foundation
import GRDB
import HAKit
import UIKit

/// AppDatabaseUpdater coordinates fetching data from servers and persisting it into the local database.
/// It ensures only one global update runs at a time, applies per-server throttling with backoff,
/// and performs bounded parallel per-server updates with careful cancellation and batched DB writes.
public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update() async
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    enum UpdateError: Error {
        case noAPI
    }

    private var lastUpdate: Date?
    // Legacy task reference (kept for compatibility/cancellation); work is now serialized by `currentUpdateTask`.
    private var updateTask: Task<Void, Never>?
    // Single in-flight global update task. Additional calls to `update()` await this task.
    private var currentUpdateTask: Task<Void, Never>?

    // Simple adaptive throttling/backoff
    // - Tracks consecutive failures per server to increase delay between attempts.
    // - Tracks per-server last successful (or attempted) update times to avoid over-fetching.
    private var consecutiveFailuresByServer: [String: Int] = [:]
    private var perServerLastUpdate: [String: Date] = [:]
    // Base throttle applied to all servers; backoff is added on top of this.
    private let baseThrottleSeconds: TimeInterval = 120
    // Maximum number of servers updated concurrently within a single global update run.
    private let maxParallelServers = 2

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
        // Cancel legacy task (if any)
        updateTask?.cancel()
        updateTask = nil
        // Cancel the serialized global update task
        currentUpdateTask?.cancel()
        currentUpdateTask = nil
        // Reset backoff tracking to free memory and avoid stale penalties
        consecutiveFailuresByServer.removeAll()
    }

    /// Starts an update if none is currently running.
    /// - Ensures only one global update runs at a time by awaiting `currentUpdateTask` if present.
    /// - Applies a global throttle (120s) and per-server throttling with exponential backoff on failures.
    /// - Executes per-server updates with bounded concurrency to balance throughput and resource usage.
    func update() async {
        // If another update is running, wait for it to complete instead of starting a new one.
        if let task = currentUpdateTask {
            Current.Log.verbose("Update already in progress, awaiting existing task")
            await task.value
            return
        }

        // Global throttle to avoid re-running too frequently regardless of server state.
        guard shouldPerformUpdate() else { return }

        lastUpdate = Date()
        Current.Log.verbose("Updating database, servers count \(Current.servers.all.count)")

        // Launch the serialized global update task. It will clear itself on completion via `defer`.
        currentUpdateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.currentUpdateTask = nil }

            await performServerUpdates()
        }

        if let task = currentUpdateTask {
            await task.value
        }
    }

    /// Checks if enough time has passed since the last update based on global throttle.
    private func shouldPerformUpdate() -> Bool {
        if let lastUpdate, lastUpdate.timeIntervalSinceNow > -120 {
            Current.Log.verbose("Skipping database update, last update was \(lastUpdate)")
            return false
        }
        return true
    }

    /// Filters servers that should be updated based on connection status and per-server throttling.
    private func filterServersToUpdate() -> [Server] {
        Current.servers.all.filter { server in
            shouldUpdateServer(server)
        }
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

    /// Performs bounded parallel updates for all eligible servers.
    private func performServerUpdates() async {
        guard !Task.isCancelled else { return }

        let serversToUpdate = filterServersToUpdate()
        guard !Task.isCancelled else { return }

        // Bounded parallelism: keep up to `maxParallelServers` updates in-flight.
        // This improves throughput while limiting DB/network contention.
        await withTaskGroup(of: (String, Bool).self) { group in
            var inFlight = 0
            var iterator = serversToUpdate.makeIterator()

            // Schedules the next server update if capacity allows and not cancelled.
            func scheduleNext() {
                if Task.isCancelled { return }
                guard inFlight < self.maxParallelServers, let server = iterator.next() else { return }
                inFlight += 1
                group.addTask { [weak self] in
                    guard let self else { return (server.identifier.rawValue, false) }
                    if Task.isCancelled { return (server.identifier.rawValue, false) }
                    let success = await safeUpdateServer(server: server)
                    return (server.identifier.rawValue, success)
                }
            }

            // Prime initial tasks
            for _ in 0 ..< self.maxParallelServers {
                scheduleNext()
            }

            while let result = await group.next() {
                inFlight -= 1
                let (serverId, success) = result
                updateServerTracking(serverId: serverId, success: success)
                scheduleNext()
            }
        }
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
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
            await withCheckedContinuation { (continuation: CheckedContinuation<
                [EntityRegistryEntry]?,
                Never
            >) in
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
            await withCheckedContinuation { (continuation: CheckedContinuation<
                [DeviceRegistryEntry]?,
                Never
            >) in
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
            await withCheckedContinuation { (continuation: CheckedContinuation<
                EntityRegistryListForDisplay?,
                Never
            >) in
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else { return }
                Current.database().asyncWrite { [entitiesListForDisplay] db in
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else { return }
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else { return }
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
}
