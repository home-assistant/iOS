import Foundation
import GRDB

public final class ControlEntityProvider {
    public enum States: String {
        case open
        case opening
        case close
        case closing
        case on
        case off
    }

    public let domains: [Domain]

    public init(domains: [Domain]) {
        self.domains = domains
    }

    public func currentState(serverId: String, entityId: String) async throws -> String? {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let connection = Current.api(for: server)?.connection else {
            return nil
        }
        let state: String? = await withCheckedContinuation { continuation in
            connection.send(.init(
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
                var entities: [HAAppEntity] = try Current.database.read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(domains.map(\.rawValue).contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
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
