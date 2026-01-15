import Foundation
import GRDB
import HAKit
import UIKit

public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update() async
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    enum UpdateError: Error {
        case noAPI
    }

    static var shared = AppDatabaseUpdater()

    private var lastUpdate: Date?
    private var updateTask: Task<Void, Never>?
    private var currentUpdateTask: Task<Void, Never>?

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

    func stop() {
        updateTask?.cancel()
        updateTask = nil
        currentUpdateTask?.cancel()
        currentUpdateTask = nil
    }

    func update() async {
        // If an update is already running, wait for it to finish
        if let task = currentUpdateTask {
            Current.Log.verbose("Update already in progress, awaiting existing task")
            await task.value
            return
        }

        if let lastUpdate, lastUpdate.timeIntervalSinceNow > -120 {
            Current.Log.verbose("Skipping database update, last update was \(lastUpdate)")
            return
        } else {
            lastUpdate = Date()
        }

        Current.Log.verbose("Updating database, servers count \(Current.servers.all.count)")

        currentUpdateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.currentUpdateTask = nil }

            for server in Current.servers.all {
                guard server.info.connection.activeURL() != nil else {
                    continue
                }
                if Task.isCancelled {
                    Current.Log.verbose("Update task cancelled")
                    break
                }
                await updateServer(server: server)
            }
        }

        if let task = currentUpdateTask {
            await task.value
        }
    }

    private func updateServer(server: Server) async {
        // Entities (fetch_states)
        await updateEntitiesDatabase(server: server)

        // Entities registry list for display
        await updateEntitiesRegistryListForDisplay(server: server)

        // Entities registry
        await updateEntitiesRegistry(server: server)

        // Devices registry
        await updateDevicesRegistry(server: server)

        // Areas with their entities
        // IMPORTANT: This must be executed after entities and device registry
        // since we rely on that data to map entities to areas
        await updateAreasDatabase(server: server)
    }

    private func updateEntitiesDatabase(server: Server) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let api = Current.api(for: server) else {
                Current.Log.error("No API available for server \(server.info.name)")
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

    private func updateEntitiesRegistry(server: Server) async {
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

    private func updateDevicesRegistry(server: Server) async {
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

    private func updateEntitiesRegistryListForDisplay(server: Server) async {
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

    private func saveEntityRegistryListForDisplay(_ response: EntityRegistryListForDisplay, serverId: String) async {
        // Check for cancellation before starting database work
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping EntityRegistryListForDisplay database save - task cancelled")
            return
        }

        let entitiesListForDisplay = response.entities.filter({ $0.decimalPlaces != nil || $0.entityCategory != nil })
            .map { registry in
                AppEntityRegistryListForDisplay(
                    id: ServerEntity.uniqueId(serverId: serverId, entityId: registry.entityId),
                    serverId: serverId,
                    entityId: registry.entityId,
                    registry: registry
                )
            }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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

    private func saveEntityRegistry(_ registryEntries: [EntityRegistryEntry], serverId: String) async {
        // Check for cancellation before starting database work
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping entity registry database save - task cancelled")
            return
        }

        let appEntityRegistries = registryEntries.map { entry in
            AppEntityRegistry(serverId: serverId, registry: entry)
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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

    private func saveDeviceRegistry(_ registryEntries: [DeviceRegistryEntry], serverId: String) async {
        // Check for cancellation before starting database work
        guard !Task.isCancelled else {
            Current.Log.verbose("Skipping device registry database save - task cancelled")
            return
        }

        let appDeviceRegistries = registryEntries.map { entry in
            AppDeviceRegistry(serverId: serverId, registry: entry)
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
