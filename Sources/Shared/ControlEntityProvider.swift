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

        public init(value: String, unitOfMeasurement: String?, domainState: Domain.State?) {
            self.value = value
            self.unitOfMeasurement = unitOfMeasurement
            self.domainState = domainState
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
                    let deviceMap = entities.devicesMap(for: server.identifier.rawValue)
                    let areasMap = entities.areasMap(for: server.identifier.rawValue)
                    entities = entities.filter({ entity in
                        let matchName = entity.name.range(
                            of: string,
                            options: [.caseInsensitive, .diacriticInsensitive]
                        ) != nil
                        let matchEntityId = entity.entityId.range(
                            of: string,
                            options: [.caseInsensitive, .diacriticInsensitive]
                        ) != nil
                        let matchDeviceName = {
                            if let deviceName = deviceMap[entity.entityId]?.name {
                                return deviceName
                                    .range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                            } else {
                                return false
                            }
                        }()
                        let matchAreaName = {
                            if let areaName = areasMap[entity.entityId]?.name {
                                return areaName
                                    .range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                            } else {
                                return false
                            }
                        }()
                        return matchName || matchEntityId || matchDeviceName || matchAreaName
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
        stateValue = stateValue.capitalizedFirst

        let domain = Domain(entityId: entityId)
        if let deviceClass = {
            let rawDeviceClass = (state?["attributes"] as? [String: Any])?["device_class"] as? String
            return DeviceClass(rawValue: rawDeviceClass ?? "")
        }(),
            let domainState = Domain.State(rawValue: stateValue.lowercased()),
            unitOfMeasurement == nil,
            let stateForDeviceClass = domain?.stateForDeviceClass(deviceClass, state: domainState) {
            return .init(
                value: stateForDeviceClass,
                unitOfMeasurement: nil,
                domainState: domainState
            )
        } else {
            return .init(
                value: stateValue,
                unitOfMeasurement: unitOfMeasurement,
                domainState: Domain.State(rawValue: stateValue.lowercased())
            )
        }
    }
}
