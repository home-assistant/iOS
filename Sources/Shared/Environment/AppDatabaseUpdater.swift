import Foundation
import GRDB
import HAKit

public protocol AppDatabaseUpdaterProtocol {
    func stop()
    func update()
}

final class AppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    static var shared = AppDatabaseUpdater()

    private var requestTokens: [HACancellable?] = []
    private var lastUpdate: Date?

    func stop() {
        cancelOnGoingRequests()
    }

    func update() {
        cancelOnGoingRequests()

        if let lastUpdate, lastUpdate.timeIntervalSinceNow > -5 {
            Current.Log.verbose("Skipping database update, last update was \(lastUpdate)")
            return
        } else {
            lastUpdate = Date()
        }

        Current.Log.verbose("Updating database, servers count \(Current.servers.all.count)")
        Current.servers.all.forEach { server in
            guard server.info.connection.activeURL() != nil else { return }

            // Cache entities
            let requestToken = Current.api(for: server)?.connection.send(
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
            requestTokens.append(requestToken)

            // Cache entities registry list for display
            let requestToken2 = Current.api(for: server)?.connection.send(
                HATypedRequest<EntityRegistryListForDisplay>.fetchEntityRegistryListForDisplay(),
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
            requestTokens.append(requestToken2)
        }
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
            try Current.database.write { db in
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
