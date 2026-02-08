import AppIntents
import Foundation
import HAKit
import Shared

// MARK: - Toggle Fan Intent

@available(iOS 18, *)
struct ToggleFanIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Fan"
    static var isDiscoverable = false

    @Parameter(title: "Fan")
    var fan: IntentFanEntity

    @Parameter(title: "Turn On")
    var turnOn: Bool

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == fan.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let service = turnOn ? Service.turnOn.rawValue : Service.turnOff.rawValue

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.fan.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": fan.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Set Fan Speed Intent

@available(iOS 18, *)
struct SetFanSpeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Fan Speed"
    static var isDiscoverable = false

    @Parameter(title: "Fan")
    var fan: IntentFanEntity

    @Parameter(title: "Speed Percentage")
    var percentage: Int

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == fan.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.fan.rawValue),
                service: "set_percentage",
                data: [
                    "entity_id": fan.entityId,
                    "percentage": percentage,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Toggle Fan Oscillation Intent

@available(iOS 18, *)
struct ToggleFanOscillationIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Fan Oscillation"
    static var isDiscoverable = false

    @Parameter(title: "Fan")
    var fan: IntentFanEntity

    @Parameter(title: "Oscillating")
    var oscillating: Bool

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == fan.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.fan.rawValue),
                service: "oscillate",
                data: [
                    "entity_id": fan.entityId,
                    "oscillating": oscillating,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Set Fan Direction Intent

@available(iOS 18, *)
struct SetFanDirectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Fan Direction"
    static var isDiscoverable = false

    @Parameter(title: "Fan")
    var fan: IntentFanEntity

    @Parameter(title: "Direction")
    var direction: String

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == fan.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.fan.rawValue),
                service: "set_direction",
                data: [
                    "entity_id": fan.entityId,
                    "direction": direction,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}
