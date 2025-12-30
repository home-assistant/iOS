import Foundation
import GRDB
import HAKit
import UIKit

public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update() async
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    static var shared = AppDatabaseUpdater()

    private var requestTokens: [HACancellable?] = []
    private var lastUpdate: Date?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func stop() {
        cancelOnGoingRequests()
    }

    func update() async {
        cancelOnGoingRequests()

        if let lastUpdate, lastUpdate.timeIntervalSinceNow > -5 {
            Current.Log.verbose("Skipping database update, last update was \(lastUpdate)")
            return
        } else {
            lastUpdate = Date()
        }

        Current.Log.verbose("Updating database, servers count \(Current.servers.all.count)")

        for server in Current.servers.all {
            guard server.info.connection.activeURL() != nil else { continue }
            // Cache entities
            let entitiesDatabaseToken = updateEntitiesDatabase(server: server)
            requestTokens.append(entitiesDatabaseToken)

            // Cache entities registry list for display
            let entitiesRegistryToken = updateEntitiesRegistryListForDisplay(server: server)
            requestTokens.append(entitiesRegistryToken)

            // Cache areas with their entities
            await updateAreasDatabase(server: server)
        }
    }

    private func updateEntitiesDatabase(server: Server) -> HACancellable? {
        Current.api(for: server)?.connection.send(
            HATypedRequest<[HAEntity]>.fetchStates(),
            completion: { result in
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
            }
        )
    }

    private func updateEntitiesRegistryListForDisplay(server: Server) -> HACancellable? {
        Current.api(for: server)?.connection.send(
            HATypedRequest<EntityRegistryListForDisplay>.configEntityRegistryListForDisplay(),
            completion: { [weak self] result in
                switch result {
                case let .success(response):
                    self?.saveEntityRegistryListForDisplay(response, serverId: server.identifier.rawValue)
                case let .failure(error):
                    Current.Log.error("Failed to fetch EntityRegistryListForDisplay: \(error)")
                    Current.clientEventStore.addEvent(.init(
                        text: "Failed to fetch EntityRegistryListForDisplay on server \(server.info.name)",
                        type: .networkRequest,
                        payload: [
                            "error": error.localizedDescription,
                        ]
                    ))
                }
            }
        )
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
        areas: [HAAreaResponse],
        areasAndEntities: [String: Set<String>],
        serverId: String
    ) async {
        let appAreas = areas.map { area in
            AppArea(
                from: area,
                serverId: serverId,
                entities: areasAndEntities[area.areaId]
            )
        }

        do {
            try await Current.database().write { db in
                // Delete existing areas for this server
                try AppArea
                    .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                    .deleteAll(db)

                // Insert new areas
                for area in appAreas {
                    try area.save(db)
                }
            }
            Current.Log.verbose("Successfully saved \(appAreas.count) areas for server \(serverId)")
        } catch {
            Current.Log.error("Failed to save areas in database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save areas in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
        }
    }

    @objc private func enterBackground() {
        cancelOnGoingRequests()
    }

    private func saveEntityRegistryListForDisplay(_ response: EntityRegistryListForDisplay, serverId: String) {
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
            try Current.database().write { db in
                try AppEntityRegistryListForDisplay
                    .filter(Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == serverId)
                    .deleteAll(db)
                for record in entitiesListForDisplay {
                    try record.save(db)
                }
            }
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
        }
    }

    private func cancelOnGoingRequests() {
        requestTokens.forEach { $0?.cancel() }
        requestTokens = []
    }
}
