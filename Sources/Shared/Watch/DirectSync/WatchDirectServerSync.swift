#if os(watchOS)
import Foundation
import GRDB
import HAAPI
import HAKit
import PromiseKit

/// Fetches one server's reference data over a direct websocket connection and writes it into the
/// watch's GRDB — the same tables, ordering, and write semantics as the iPhone's
/// `AppDatabaseUpdater.updateServer`. One-shot lifecycle: connect → fetch → disconnect (watchOS
/// gives sockets foreground runtime only, and the database is suspended in background).
struct WatchDirectServerSync {
    /// Domains the watch stores as addable entities (mirrors the iPhone watch picker).
    private static var mirroredDomains: Set<String> {
        [Domain.script.rawValue, Domain.scene.rawValue, Domain.automation.rawValue]
    }

    let server: Server

    func run() async throws {
        let connection = HAAPIConnection(configuration: ServerHAAPIAdapter.configuration(for: server))
        await connection.connect()
        do {
            try await sync(over: connection)
            await connection.disconnect()
        } catch {
            await connection.disconnect()
            throw error
        }
    }

    /// Sequential on purpose: the registry must be saved before entities so `AppEntitiesModel`
    /// bakes registry names into `HAAppEntity.name`, and devices before areas so the area→entity
    /// composition sees device-inherited areas (same ordering contract as `AppDatabaseUpdater`).
    private func sync(over connection: HAAPIConnection) async throws {
        let serverId = server.identifier.rawValue

        // Step 1: entity registry (`list_for_display`).
        let registryValue = try await connection.send(command: "config/entity_registry/list_for_display")
        let registry = try HAAPIDataBridge.decode(EntityRegistryListForDisplay.self, from: registryValue)
        try await saveEntityRegistry(registry, serverId: serverId)

        // Step 2: states → HAAppEntity (scripts/scenes/automations) and AppZone (zones).
        let statesValue = try await connection.send(command: "get_states")
        let states = HAAPIDataBridge.decodeArrayLeniently(HAEntity.self, from: statesValue)
        let mirroredEntities = states.filter { Self.mirroredDomains.contains($0.domain) }
        await Current.appEntitiesModel().updateModel(Set(mirroredEntities), server: server)
        try await storeZones(states.filter { $0.domain == Domain.zone.rawValue })

        // Step 3: device registry (needed for the area→entity composition below).
        let devicesValue = try await connection.send(command: "config/device_registry/list")
        let devices = try HAAPIDataBridge.decodeArray(DeviceRegistryEntry.self, from: devicesValue)
        try await saveDeviceRegistry(devices, serverId: serverId)

        // Step 4: areas (+ floors when referenced), composed with the just-saved registries.
        let areasValue = try await connection.send(command: "config/area_registry/list")
        let areas = try HAAPIDataBridge.decodeArray(HAAreasRegistryResponse.self, from: areasValue)
        var floors: [HAFloorRegistryResponse] = []
        if areas.contains(where: { $0.floorId != nil }) {
            let floorsValue = try await connection.send(command: "config/floor_registry/list")
            floors = (try? HAAPIDataBridge.decodeArray(HAFloorRegistryResponse.self, from: floorsValue)) ?? []
        }
        try await saveAreas(areas, floors: floors, serverId: serverId)

        // Step 5: Assist pipelines.
        let pipelinesValue = try await connection.send(command: "assist_pipeline/pipeline/list")
        let pipelines = try HAAPIDataBridge.decode(PipelineResponse.self, from: pipelinesValue)
        try saveAssistPipelines(pipelines, serverId: serverId)
    }

    // MARK: - Table writers (same semantics as AppDatabaseUpdater's save* methods)

    private func saveEntityRegistry(_ response: EntityRegistryListForDisplay, serverId: String) async throws {
        // The websocket payload has no server id; stamp it before persisting.
        let entities = response.entities.map { entity -> EntityRegistryListForDisplay.Entity in
            var entity = entity
            entity.serverId = serverId
            return entity
        }
        // The table has NO stable primary key, only a (serverId, entityId) unique index — the
        // delete-per-server + insert transaction below is what keeps repeat syncs from violating it.
        try await replaceServerRows(
            entities,
            serverIdColumn: DatabaseTables.DisplayEntityRegistry.serverId.rawValue,
            serverId: serverId,
            keyedBy: \.entityId
        )
    }

    private func saveDeviceRegistry(_ entries: [DeviceRegistryEntry], serverId: String) async throws {
        let rows = entries.map { AppDeviceRegistry(serverId: serverId, registry: $0) }
        try await replaceServerRows(
            rows,
            serverIdColumn: DatabaseTables.DeviceRegistry.serverId.rawValue,
            serverId: serverId,
            keyedBy: \.deviceId
        )
    }

    private func saveAreas(
        _ areas: [HAAreasRegistryResponse],
        floors: [HAFloorRegistryResponse],
        serverId: String
    ) async throws {
        let registryRows = (try? EntityRegistryListForDisplay.Entity.config(serverId: serverId)) ?? []
        let deviceRows = (try? AppDeviceRegistry.config(serverId: serverId)) ?? []
        let entitiesByArea = AreasService.getAllEntitiesFromArea(
            devicesAndAreas: deviceRows,
            entitiesAndAreas: registryRows
        )
        let floorNamesById = Dictionary(
            floors.map { ($0.floorId, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let appAreas = areas.enumerated().map { index, area in
            AppArea(
                from: area,
                serverId: serverId,
                entities: entitiesByArea[area.areaId],
                sortOrder: index,
                floorName: area.floorId.flatMap { floorNamesById[$0] }
            )
        }
        try await replaceServerRows(
            appAreas,
            serverIdColumn: DatabaseTables.AppArea.serverId.rawValue,
            serverId: serverId,
            keyedBy: \.id
        )
    }

    private func saveAssistPipelines(_ response: PipelineResponse, serverId: String) throws {
        // Single row per server — same semantics as `AssistService.saveInDatabase`.
        let assistPipeline = AssistPipelines(serverId: serverId, pipelineResponse: response)
        _ = try Current.database().write { db in
            try AssistPipelines.filter(
                Column(DatabaseTables.AssistPipelines.serverId.rawValue) == serverId
            ).deleteAll(db)
            try assistPipeline.save(db)
        }
    }

    private func storeZones(_ zones: [HAEntity]) async throws {
        // The same upsert-and-prune store the iPhone's zone subscription funnels into.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Current.modelManager.store(type: AppZone.self, from: server, sourceModels: zones)
                .done { continuation.resume() }
                .catch { continuation.resume(throwing: $0) }
        }
    }

    /// Replaces a server's rows in one transaction, skipping the write entirely when the fresh
    /// rows match what's stored (same no-op optimization as `AppDatabaseUpdater.recordsEqual`).
    private func replaceServerRows<T: FetchableRecord & PersistableRecord & Equatable>(
        _ rows: [T],
        serverIdColumn: String,
        serverId: String,
        keyedBy key: (T) -> String
    ) async throws {
        let stored = try? await Current.database().read { db in
            try T.filter(Column(serverIdColumn) == serverId).fetchAll(db)
        }
        if let stored, recordsEqual(rows, stored, keyedBy: key) {
            return
        }
        try await Current.database().write { db in
            try T.filter(Column(serverIdColumn) == serverId).deleteAll(db)
            for row in rows {
                try row.insert(db)
            }
        }
    }

    /// Order-independent equality of two record arrays, keyed by a unique identifier. Duplicate
    /// keys on either side compare as "changed" so a write is never skipped on ambiguous data.
    private func recordsEqual<T: Equatable>(_ lhs: [T], _ rhs: [T], keyedBy key: (T) -> String) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let lhsByKey = Dictionary(lhs.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        let rhsByKey = Dictionary(rhs.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        guard lhsByKey.count == lhs.count, rhsByKey.count == rhs.count else { return false }
        return lhsByKey == rhsByKey
    }
}
#endif
