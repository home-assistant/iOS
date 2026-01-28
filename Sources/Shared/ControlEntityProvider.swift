import Foundation
import GRDB
import HAKit
import SwiftUI

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
        public let color: Color?

        public init(value: String, unitOfMeasurement: String?, domainState: Domain.State?, color: Color? = nil) {
            self.value = value
            self.unitOfMeasurement = unitOfMeasurement
            self.domainState = domainState
            self.color = color
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

        guard let data = try? result.get() else {
            if case let .failure(error) = result {
                Current.Log.error("Failed to get state: \(error)")
            }
            return nil
        }

        guard case let .dictionary(state) = data else {
            Current.Log.error("Failed to get state bad response data")
            return nil
        }

        var stateValue = (state["state"] as? String) ?? "N/A"
        stateValue = StatePrecision.adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: entityId,
            stateValue: stateValue
        )
        stateValue = stateValue.capitalizedFirst

        let attributes = state["attributes"] as? [String: Any]
        let colorAttributes = parseColorAttributes(from: attributes)
        let unitOfMeasurement = attributes?["unit_of_measurement"] as? String

        return buildState(
            entityId: entityId,
            stateValue: stateValue,
            attributes: attributes,
            colorAttributes: colorAttributes,
            unitOfMeasurement: unitOfMeasurement
        )
    }

    private func parseColorAttributes(from attributes: [String: Any]?) -> (
        colorMode: String?,
        rgbColor: [Int]?,
        hsColor: [Double]?
    ) {
        guard let attributes else {
            return (nil, nil, nil)
        }

        let colorMode = attributes["color_mode"] as? String
        let rgbColor = parseRGBColor(from: attributes["rgb_color"])
        let hsColor = parseHSColor(from: attributes["hs_color"])

        return (colorMode, rgbColor, hsColor)
    }

    private func parseRGBColor(from value: Any?) -> [Int]? {
        if let rgb = value as? [Int], rgb.count == 3 {
            return rgb
        }
        if let rgbAny = value as? [Any] {
            let ints = rgbAny.compactMap { $0 as? Int }
            return ints.count == 3 ? ints : nil
        }
        return nil
    }

    private func parseHSColor(from value: Any?) -> [Double]? {
        if let hs = value as? [Double], hs.count >= 2 {
            return Array(hs.prefix(2))
        }
        if let hsAny = value as? [Any] {
            let doubles = hsAny.compactMap { value -> Double? in
                if let d = value as? Double { return d }
                if let n = value as? NSNumber { return n.doubleValue }
                if let s = value as? String, let d = Double(s) { return d }
                return nil
            }
            return doubles.count >= 2 ? Array(doubles.prefix(2)) : nil
        }
        return nil
    }

    private func buildState(
        entityId: String,
        stateValue: String,
        attributes: [String: Any]?,
        colorAttributes: (colorMode: String?, rgbColor: [Int]?, hsColor: [Double]?),
        unitOfMeasurement: String?
    ) -> State {
        let domain = Domain(entityId: entityId)
        let domainState = Domain.State(rawValue: stateValue.lowercased())

        if let deviceClass = extractDeviceClass(from: attributes),
           let domainState,
           unitOfMeasurement == nil,
           let stateForDeviceClass = domain?.stateForDeviceClass(deviceClass, state: domainState) {
            let computedColor = computeIconColor(
                entityId: entityId,
                stateValue: stateValue,
                colorAttributes: colorAttributes
            )
            return .init(
                value: stateForDeviceClass,
                unitOfMeasurement: nil,
                domainState: domainState,
                color: computedColor
            )
        } else {
            let computedColor = computeIconColor(
                entityId: entityId,
                stateValue: stateValue,
                colorAttributes: colorAttributes
            )
            return .init(
                value: stateValue,
                unitOfMeasurement: unitOfMeasurement,
                domainState: domainState,
                color: computedColor
            )
        }
    }

    private func extractDeviceClass(from attributes: [String: Any]?) -> DeviceClass? {
        guard let rawDeviceClass = attributes?["device_class"] as? String else {
            return nil
        }
        return DeviceClass(rawValue: rawDeviceClass)
    }

    private func computeIconColor(
        entityId: String,
        stateValue: String,
        colorAttributes: (colorMode: String?, rgbColor: [Int]?, hsColor: [Double]?)
    ) -> Color? {
        EntityIconColorProvider.iconColor(
            domain: Domain(entityId: entityId) ?? .switch,
            state: stateValue.lowercased(),
            colorMode: colorAttributes.colorMode,
            rgbColor: colorAttributes.rgbColor,
            hsColor: colorAttributes.hsColor
        )
    }
}
