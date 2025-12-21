import Foundation
import GRDB
import HAKit

public final class ControlEntityProvider {
    public enum States: String {
        case open
        case opening
        case close
        case closing
        case on
        case off
    }

    public struct State {
        public let value: String
        public let unitOfMeasurement: String?
        public let domainState: Domain.State?
        public let deviceClass: String?

        public init(value: String, unitOfMeasurement: String?, domainState: Domain.State?, deviceClass: String? = nil) {
            self.value = value
            self.unitOfMeasurement = unitOfMeasurement
            self.domainState = domainState
            self.deviceClass = deviceClass
        }
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
                var entities: [HAAppEntity] = try Current.database().read { db in
                    if domains.isEmpty {
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .fetchAll(db)
                    } else {
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(domains.map(\.rawValue).contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
                            .fetchAll(db)
                    }
                }
                if let string {
                    // Fetch all areas for this server once and create a lookup map
                    let areas: [AppArea]
                    do {
                        areas = try AppArea.fetchAreas(for: server.identifier.rawValue)
                    } catch {
                        Current.Log.error("Failed to fetch areas for entity filtering: \(error.localizedDescription)")
                        areas = []
                    }
                    var entityToAreaMap: [String: String] = [:]
                    for area in areas {
                        for entityId in area.entities {
                            entityToAreaMap[entityId] = area.name
                        }
                    }

                    entities = entities.filter({ entity in
                        let matchName = entity.name.range(
                            of: string,
                            options: [.caseInsensitive, .diacriticInsensitive]
                        ) != nil
                        let matchEntityId = entity.entityId.range(
                            of: string,
                            options: [.caseInsensitive, .diacriticInsensitive]
                        ) != nil
                        let matchAreaName = {
                            if let area = entityToAreaMap[entity.entityId] {
                                return area.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                            } else {
                                return false
                            }
                        }()
                        return matchName || matchEntityId || matchAreaName
                    })
                }
                entitiesPerServer.append((server, entities))
            } catch {
                Current.Log.error("Failed to load entities from database: \(error.localizedDescription)")
            }
        }

        return entitiesPerServer
    }

    public func state(server: Server, entityId: String) async -> State? {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch state data")
            return nil
        }

        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.get, "states/\(entityId)"),
                shouldRetry: true
            )) { result in
                continuation.resume(returning: result)
            }
        }

        var data: HAData?
        switch result {
        case let .success(resultData):
            data = resultData
        case let .failure(error):
            Current.Log.error("Failed to get state: \(error)")
            return nil
        }

        guard let data else {
            return nil
        }

        var state: [String: Any]?
        switch data {
        case let .dictionary(response):
            state = response
        default:
            Current.Log.error("Failed to get state bad response data")
            return nil
        }

        var stateValue = (state?["state"] as? String) ?? "N/A"
        stateValue = StatePrecision.adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: entityId,
            stateValue: stateValue
        )
        let unitOfMeasurement = (state?["attributes"] as? [String: Any])?["unit_of_measurement"] as? String
        let deviceClass = (state?["attributes"] as? [String: Any])?["device_class"] as? String
        stateValue = stateValue.capitalizedFirst
        return .init(
            value: stateValue,
            unitOfMeasurement: unitOfMeasurement,
            domainState: .init(rawValue: stateValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
            deviceClass: deviceClass
        )
    }
}
