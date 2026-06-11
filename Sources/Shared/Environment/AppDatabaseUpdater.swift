import Foundation
import GRDB
import HAKit
import UIKit

// MARK: - AppDatabaseUpdater

/// AppDatabaseUpdater coordinates fetching data from servers and persisting it into the local database.
/// It ensures only one update per server runs at a time (different servers can update concurrently),
/// applies per-server throttling with backoff, and performs careful cancellation and batched DB writes.
public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update(server: Server, forceUpdate: Bool)
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    enum UpdateError: Error {
        case noAPI
    }

    // MARK: - Cancellation Helper

    // Cached foreground state. `UIApplication.applicationState` is a main-thread-only API, but
    // `isUpdateCancelled()` runs on background tasks and is called at every step/continuation.
    // We mirror the foreground state here via lifecycle notifications (delivered on the main thread)
    // and read it through a lock, so the hot cancellation path never touches UIKit off the main thread.
    private let foregroundLock = NSLock()
    private var _isForeground = true

    private var isForeground: Bool {
        foregroundLock.lock()
        defer { foregroundLock.unlock() }
        return _isForeground
    }

    private func setForeground(_ value: Bool) {
        foregroundLock.lock()
        defer { foregroundLock.unlock() }
        _isForeground = value
    }

    /// Centralized cancellation check that can be customized in the future.
    /// Returns `true` if the current task has been cancelled or the app is no longer in the foreground.
    private func isUpdateCancelled() -> Bool {
        Task.isCancelled || !isForeground
    }

    // Actor for thread-safe task management and queuing
    private actor TaskCoordinator {
        private var currentUpdateTasks: [String: Task<Void, Never>] = [:]
        private var updateQueue: [(serverId: String, task: () async -> Void)] = []
        // Servers that currently have work queued or running, mapped to the strongest pending force
        // level. Presence dedupes redundant updates; the value lets a forced request upgrade a queued
        // non-forced one so a user-triggered refresh isn't dropped (and later throttled into a no-op).
        // Mutated only within the actor, so membership always reflects the true queued-or-running set
        // (no gap between dequeue and start that a duplicate could slip through).
        private var pendingForceByServer: [String: Bool] = [:]
        private var isProcessingQueue = false

        func setTask(_ task: Task<Void, Never>, for serverId: String) {
            currentUpdateTasks[serverId] = task
        }

        func removeTask(for serverId: String) {
            currentUpdateTasks.removeValue(forKey: serverId)
        }

        /// The force level the server's queued/running work should run with (default non-forced).
        func effectiveForce(for serverId: String) -> Bool {
            pendingForceByServer[serverId] ?? false
        }

        func cancelAllTasks() {
            for (_, task) in currentUpdateTasks {
                task.cancel()
            }
            currentUpdateTasks.removeAll()
            updateQueue.removeAll()
            pendingForceByServer.removeAll()
            isProcessingQueue = false
        }

        /// Enqueues a server update task to be processed sequentially.
        /// Skips servers that already have work queued or in progress, but a forced request upgrades
        /// an existing non-forced one so the eventual run isn't throttled away.
        func enqueueUpdate(serverId: String, forceUpdate: Bool, task: @escaping () async -> Void) {
            if let existingForce = pendingForceByServer[serverId] {
                if forceUpdate, !existingForce {
                    pendingForceByServer[serverId] = true
                    Current.Log.verbose("Upgrading queued update for server \(serverId) to forced")
                } else {
                    Current.Log.verbose("Update for server \(serverId) already queued or running, skipping duplicate")
                }
                return
            }
            pendingForceByServer[serverId] = forceUpdate
            updateQueue.append((serverId: serverId, task: task))

            // Start processing if not already running
            if !isProcessingQueue {
                Task {
                    await processQueue()
                }
            }
        }

        /// Processes queued updates one at a time
        private func processQueue() async {
            guard !isProcessingQueue else { return }
            isProcessingQueue = true

            while !updateQueue.isEmpty {
                let queuedUpdate = updateQueue.removeFirst()
                Current.Log.verbose("Processing queued update for server: \(queuedUpdate.serverId)")
                await queuedUpdate.task()
                pendingForceByServer.removeValue(forKey: queuedUpdate.serverId)
            }

            isProcessingQueue = false
        }
    }

    private let taskCoordinator = TaskCoordinator()

    // Simple adaptive throttling/backoff
    // - Tracks consecutive failures per server to increase delay between attempts.
    // - Tracks per-server last successful (or attempted) update times to avoid over-fetching.
    // These are read/written from detached update tasks; `stop()` resets only
    // `consecutiveFailuresByServer` from the main thread (last-update times are intentionally kept so
    // throttling survives background/foreground transitions). All access is serialized through `throttleLock`.
    private let throttleLock = NSLock()
    private var consecutiveFailuresByServer: [String: Int] = [:]
    private var perServerLastUpdate: [String: Date] = [:]
    // Base throttle applied to all servers; backoff is added on top of this.
    private let baseThrottleSeconds: TimeInterval = 120

    static var shared = AppDatabaseUpdater()

    init() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(enterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Seed the cached foreground state on the main thread. `didBecomeActiveNotification`
        // won't re-fire if the app is already active when the observer is registered.
        DispatchQueue.main.async { [weak self] in
            self?.setForeground(Current.isForegroundApp())
        }
    }

    @objc private func enterBackground() {
        setForeground(false)
        stop()
    }

    @objc private func didBecomeActive() {
        setForeground(true)
    }

    @objc private func willResignActive() {
        setForeground(false)
    }

    /// Cancels any in-flight work and clears transient state.
    /// Called when app enters background or when we need to abort updates early.
    func stop() {
        Task {
            await taskCoordinator.cancelAllTasks()
        }

        // Reset backoff tracking to free memory and avoid stale penalties
        throttleLock.lock()
        consecutiveFailuresByServer.removeAll()
        throttleLock.unlock()
    }

    /// Starts an update for a specific server in the background.
    /// This method returns immediately and does not block the caller.
    /// - Parameter server: The specific server to update.
    /// - Parameter forceUpdate: Forces update regardless of other conditions
    /// - Server updates are queued and processed sequentially, one at a time.
    /// - Applies per-server throttling with exponential backoff on failures.
    func update(server: Server, forceUpdate: Bool) {
        // Explicitly detach from the calling context to ensure we don't block the main thread
        // Returns immediately while work continues in the background
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let serverId = server.identifier.rawValue

            // Enqueue the update to be processed sequentially
            await taskCoordinator.enqueueUpdate(serverId: serverId, forceUpdate: forceUpdate) { [weak self] in
                guard let self else { return }

                Current.Log.verbose("Updating database for server \(server.info.name)")

                // Launch the server-specific update task. The effective force level is read inside
                // `performSingleServerUpdate`, immediately before the throttle check, so a forced
                // request that upgraded this entry is honored even if it arrives after dequeue.
                let updateTask = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        // Clean up task reference when complete
                        Task {
                            await self.taskCoordinator.removeTask(for: serverId)
                        }
                    }

                    await performSingleServerUpdate(server: server)
                }

                // Store the task for this server
                await taskCoordinator.setTask(updateTask, for: serverId)

                await updateTask.value
            }
        }
    }

    /// Determines if a specific server should be updated based on connection and throttle rules.
    private func shouldUpdateServer(_ server: Server, forceUpdate: Bool) -> Bool {
        guard server.info.connection.activeURL() != nil else { return false }
        if isUpdateCancelled() { return false }

        // Skip throttle checks if forceUpdate is true
        if forceUpdate {
            return true
        }

        // Per-server throttle with exponential backoff
        throttleLock.lock()
        defer { throttleLock.unlock() }
        let serverId = server.identifier.rawValue
        if let last = perServerLastUpdate[serverId] {
            let failures = consecutiveFailuresByServer[serverId] ?? 0
            let backoff = min(pow(2.0, Double(failures)) * 10.0, 300.0) // 10s, 20s, 40s... up to 5m
            let threshold = -(baseThrottleSeconds + backoff)
            return last.timeIntervalSinceNow <= threshold
        }
        return true
    }

    /// Performs an update for a single specific server.
    private func performSingleServerUpdate(server: Server) async {
        guard !isUpdateCancelled() else { return }
        // Read the effective force as late as possible — immediately before the throttle decision —
        // so a forced request that upgraded this server's queued entry isn't throttled into a no-op.
        let forceUpdate = await taskCoordinator.effectiveForce(for: server.identifier.rawValue)
        guard shouldUpdateServer(server, forceUpdate: forceUpdate) else {
            Current.Log.verbose("Skipping update for server \(server.info.name) - throttled")
            return
        }

        // `nil` means the update was cancelled (e.g. app backgrounded); skip tracking entirely so
        // cancellation isn't recorded as a failure (which would add a spurious backoff penalty, and
        // could re-add a failure count that `stop()` just cleared).
        guard let success = await safeUpdateServer(server: server) else { return }
        updateServerTracking(serverId: server.identifier.rawValue, success: success)
    }

    /// Updates per-server tracking after an update attempt completes.
    private func updateServerTracking(serverId: String, success: Bool) {
        throttleLock.lock()
        defer { throttleLock.unlock() }
        if success {
            perServerLastUpdate[serverId] = Date()
            consecutiveFailuresByServer[serverId] = 0
        } else {
            consecutiveFailuresByServer[serverId, default: 0] += 1
        }
    }

    /// Wraps a per-server update with cancellation checks.
    /// Returns `nil` if the update was cancelled, otherwise whether it succeeded — letting the
    /// scheduler apply backoff on failures and update last-run times on success without treating
    /// cancellation as either.
    private func safeUpdateServer(server: Server) async -> Bool? {
        if isUpdateCancelled() { return nil }
        await updateServer(server: server)
        if isUpdateCancelled() { return nil }
        return true
    }

    /// Runs the full update pipeline for a single server in sequence.
    /// Each phase checks for cancellation to bail out quickly when needed.
    ///
    /// NOTE: These fetches are deliberately sequential. The registry fetches (steps 2–5) are
    /// Home Assistant WebSocket requests, and the protocol requires each message `id` on a
    /// connection to be strictly increasing in transmission order. HAKit assigns ids and enqueues
    /// the socket write per-request, so issuing these from concurrent tasks lets frames transmit
    /// out of id order and the server rejects them with `id_reuse`
    /// ("Identifier values have to increase."). Keep them sequential.
    private func updateServer(server: Server) async {
        guard !isUpdateCancelled() else { return }

        let totalTimer = ProfilingTimer("Starting full update for server: \(server.info.name)")

        // Step 1: Entities (fetch_states)
        do {
            let timer = ProfilingTimer("Step 1 (Entities)")
            await updateEntitiesDatabase(server: server)
            timer.end()
        }
        if isUpdateCancelled() { return }

        // Step 2: Entities registry (from list-for-display)
        do {
            let timer = ProfilingTimer("Step 2 (Entities Registry)")
            await updateEntitiesRegistry(server: server)
            timer.end()
        }
        if isUpdateCancelled() { return }

        // Step 3: Devices registry
        do {
            let timer = ProfilingTimer("Step 3 (Devices Registry)")
            await updateDevicesRegistry(server: server)
            timer.end()
        }
        if isUpdateCancelled() { return }

        // Step 4: Areas with their entities
        // IMPORTANT: This must be executed after entities and device registry
        // since we rely on that data to map entities to areas
        do {
            let timer = ProfilingTimer("Step 4 (Areas)")
            await updateAreasDatabase(server: server)
            timer.end()
        }

        totalTimer.end()
        Current.Log.info("✅ [Profiling] Full update for server \(server.info.name) completed")
    }

    /// Sends a typed request for `server` and returns the decoded payload, or `nil` on cancellation,
    /// missing API, or failure. Logs and records a client event on failure. Centralizes the
    /// continuation/error boilerplate shared by every fetch step below.
    private func fetch<T>(
        _ request: HATypedRequest<T>,
        server: Server,
        failureText: String
    ) async -> T? {
        guard !isUpdateCancelled() else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            guard let api = Current.api(for: server) else {
                Current.Log.error("No API available for server \(server.info.name)")
                continuation.resume(returning: nil)
                return
            }
            // If cancelled after acquiring API, resume the continuation to avoid hanging.
            if self.isUpdateCancelled() {
                continuation.resume(returning: nil)
                return
            }
            api.connection.send(request) { result in
                switch result {
                case let .success(value):
                    continuation.resume(returning: value)
                case let .failure(error):
                    Current.Log.error("\(failureText): \(error)")
                    Current.clientEventStore.addEvent(.init(
                        text: "\(failureText) on server \(server.info.name)",
                        type: .networkRequest,
                        payload: [
                            "error": error.localizedDescription,
                        ]
                    ))
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Fetches entities' states from the API and forwards results to persistence.
    private func updateEntitiesDatabase(server: Server) async {
        // HAKit completions fire on the main queue, so resume with the raw entities and do the
        // (potentially heavy) Set construction and database work afterwards — off the main thread —
        // via the awaited `updateModel` below.
        guard let entities = await fetch(
            HATypedRequest<[HAEntity]>.fetchStates(),
            server: server,
            failureText: "Failed to fetch states"
        ) else { return }
        guard !isUpdateCancelled() else { return }
        await Current.appEntitiesModel().updateModel(Set(entities), server: server)
    }

    /// Fetches device registry from the API and forwards results to persistence.
    private func updateDevicesRegistry(server: Server) async {
        guard let registryEntries = await fetch(
            HATypedRequest<[DeviceRegistryEntry]>.configDeviceRegistryList(),
            server: server,
            failureText: "Failed to fetch device registry"
        ) else { return }
        await saveDeviceRegistry(registryEntries, serverId: server.identifier.rawValue)
    }

    /// Fetches the entity registry (via `list_for_display`) from the API and forwards it to persistence.
    private func updateEntitiesRegistry(server: Server) async {
        guard let response = await fetch(
            HATypedRequest<EntityRegistryListForDisplay>.configEntityRegistryListForDisplay(),
            server: server,
            failureText: "Failed to fetch EntityRegistryListForDisplay"
        ) else { return }
        await saveEntityRegistry(response, serverId: server.identifier.rawValue)
    }

    private func updateAreasDatabase(server: Server) async {
        // Ensure this work happens off the main thread
        await Task.detached(priority: .utility) {
            let fetchTimer = ProfilingTimer("Step 4.1: fetchAreasAndItsEntities")
            let areasAndEntities = await Current.areasProvider().fetchAreasAndItsEntities(for: server)
            fetchTimer.end()

            guard let areas = Current.areasProvider().areas[server.identifier.rawValue] else {
                Current.Log.verbose("No areas found for server \(server.info.name)")
                return
            }

            let saveTimer = ProfilingTimer("Step 4.2: saveAreasToDatabase (count: \(areas.count))")
            await self.saveAreasToDatabase(
                areas: areas,
                areasAndEntities: areasAndEntities,
                serverId: server.identifier.rawValue
            )
            saveTimer.end()
        }.value
    }

    /// Order-independent equality of two record arrays, keyed by a unique identifier.
    /// Used to skip a no-op delete+reinsert when the freshly fetched data matches what's stored.
    private func recordsEqual<T: Equatable>(_ lhs: [T], _ rhs: [T], keyedBy key: (T) -> String) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let lhsByKey = Dictionary(lhs.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        let rhsByKey = Dictionary(rhs.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        // If either side had duplicate keys, building the dictionary collapsed entries and the
        // comparison would be ambiguous. Treat that as "changed" so we never skip a write on bad data.
        guard lhsByKey.count == lhs.count, rhsByKey.count == rhs.count else { return false }
        return lhsByKey == rhsByKey
    }

    /// Persists areas and their entity relationships for a server.
    /// Deletes all existing areas for the server and inserts fresh data in a single transaction.
    private func saveAreasToDatabase(
        areas: [HAAreasRegistryResponse],
        areasAndEntities: [String: Set<String>],
        serverId: String
    ) async {
        // Check for cancellation before starting database work
        guard !isUpdateCancelled() else {
            Current.Log.verbose("Skipping areas database save - task cancelled")
            return
        }

        // Ensure model building happens off the main thread
        let appAreas = await Task.detached(priority: .utility) {
            let modelTimer = ProfilingTimer("Step 4.2.1: Building AppArea models (count: \(areas.count))")
            let result = areas.enumerated().map { index, area in
                AppArea(
                    from: area,
                    serverId: serverId,
                    entities: areasAndEntities[area.areaId],
                    sortOrder: index
                )
            }
            modelTimer.end()
            return result
        }.value

        // Skip the delete+reinsert when nothing changed (common on forced/periodic refreshes).
        if let storedAreas = try? await Current.database().read({ db in
            try AppArea.filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId).fetchAll(db)
        }), recordsEqual(appAreas, storedAreas, keyedBy: \.id) {
            Current.Log.verbose("Areas unchanged for server \(serverId), skipping database write")
            return
        }

        do {
            let dbTimer = ProfilingTimer("Step 4.2.2: Database write transaction")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Current.database().asyncWrite { db in
                    // Delete all existing areas for this server
                    try AppArea
                        .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                        .deleteAll(db)

                    // Insert fresh areas
                    for area in appAreas {
                        try area.insert(db)
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
            dbTimer.end()
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

    /// Persists the entity registry (from `list_for_display`) for a server.
    /// Deletes all existing records for the server and inserts fresh data in a single transaction.
    private func saveEntityRegistry(_ response: EntityRegistryListForDisplay, serverId: String) async {
        // If cancelled before touching the DB, bail out early to avoid unnecessary work.
        guard !isUpdateCancelled() else {
            Current.Log.verbose("Skipping entity registry database save - task cancelled")
            return
        }

        // The WebSocket payload has no server id; stamp it on each entity before persisting.
        let entities = response.entities.map { entity -> EntityRegistryListForDisplay.Entity in
            var entity = entity
            entity.serverId = serverId
            return entity
        }

        // Skip the delete+reinsert when nothing changed (common on forced/periodic refreshes).
        // The list-for-display registry is the largest payload, so avoiding a no-op rewrite saves the
        // most DB writer time. Uses GRDB's async read so the comparison fetch suspends instead of blocking.
        let storedEntityRegistry = try? await Current.database().read { db in
            try EntityRegistryListForDisplay.Entity
                .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        if let storedEntityRegistry, recordsEqual(entities, storedEntityRegistry, keyedBy: \.entityId) {
            Current.Log.verbose("Entity registry unchanged for server \(serverId), skipping database write")
            return
        }

        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard !isUpdateCancelled() else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                Current.database().asyncWrite { [entities] db in
                    // Delete all existing registry entries for this server
                    try EntityRegistryListForDisplay.Entity
                        .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                        .deleteAll(db)

                    // Insert fresh registry entries
                    for entity in entities {
                        try entity.insert(db)
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
                .verbose("Successfully saved \(entities.count) entity registry entries for server \(serverId)")
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

    /// Persists the device registry for a server.
    /// Deletes all existing records for the server and inserts fresh data in a single transaction.
    private func saveDeviceRegistry(_ registryEntries: [DeviceRegistryEntry], serverId: String) async {
        // If cancelled before touching the DB, bail out early to avoid unnecessary work.
        guard !isUpdateCancelled() else {
            Current.Log.verbose("Skipping device registry database save - task cancelled")
            return
        }

        let appDeviceRegistries = registryEntries.map { entry in
            AppDeviceRegistry(serverId: serverId, registry: entry)
        }

        // Skip the delete+reinsert when nothing changed (common on forced/periodic refreshes).
        // Uses GRDB's async read so the comparison fetch suspends instead of blocking the thread.
        let storedDeviceRegistry = try? await Current.database().read { db in
            try AppDeviceRegistry
                .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                .fetchAll(db)
        }
        if let storedDeviceRegistry, recordsEqual(appDeviceRegistries, storedDeviceRegistry, keyedBy: \.deviceId) {
            Current.Log.verbose("Device registry unchanged for server \(serverId), skipping database write")
            return
        }

        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard !isUpdateCancelled() else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                Current.database().asyncWrite { db in
                    // Delete all existing device registry entries for this server
                    try AppDeviceRegistry
                        .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                        .deleteAll(db)

                    // Insert fresh registry entries
                    for registry in appDeviceRegistries {
                        try registry.insert(db)
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

// MARK: - Profiling Helper

/// A simple timing helper that works across iOS versions
private struct ProfilingTimer {
    private let startTime: CFAbsoluteTime
    private let label: String

    init(_ label: String) {
        self.label = label
        self.startTime = CFAbsoluteTimeGetCurrent()
        Current.Log.info("🔍 [Profiling] \(label)")
    }

    func end() {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Current.Log.info("⏱️ [Profiling] \(label) completed in \(String(format: "%.3f", duration))s")
    }
}
