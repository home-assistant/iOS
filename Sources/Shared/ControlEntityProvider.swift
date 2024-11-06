import Foundation
import GRDB

public final class ControlEntityProvider {
    public enum States: String {
        case open
        case on
        case off
    }

    public let domain: Domain

    public init(domain: Domain) {
        self.domain = domain
    }

    public func currentState(serverId: String, entityId: String) async throws -> String? {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            return nil
        }
        let api = Current.api(for: server)
        let state: String? = await withCheckedContinuation { continuation in
            api.connection.send(.init(
                type: .rest(.get, "states/\(entityId)")
            )) { result in
                switch result {
                case let .success(data):
                    let state: String? = data.decode("state", fallback: nil)
                    continuation.resume(returning: state)
                case let .failure(error):
                    Current.Log.error("Failed to get \(entityId) state for ControlEntityProvider: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }

        return state
    }

    public func getEntities(matching string: String? = nil) -> [(Server, [HAAppEntity])] {
        var entitiesPerServer: [(Server, [HAAppEntity])] = []
        for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
            do {
                var entities: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == domain.rawValue)
                        .fetchAll(db)
                }
                if let string {
                    entities = entities.filter({ entity in
                        entity.name.lowercased().contains(string.lowercased())
                    })
                }
                entitiesPerServer.append((server, entities))
            } catch {
                Current.Log.error("Failed to load entities from database: \(error.localizedDescription)")
            }
        }

        return entitiesPerServer
    }
}
