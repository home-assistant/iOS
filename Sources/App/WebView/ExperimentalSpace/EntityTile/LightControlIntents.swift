import AppIntents
import Foundation
import HAKit
import Shared

// MARK: - Set Light Brightness Intent

@available(iOS 18, *)
struct SetLightBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Light Brightness"
    static var isDiscoverable = false

    @Parameter(title: "Light")
    var light: IntentLightEntity

    @Parameter(title: "Brightness")
    var brightness: Int

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: Service.turnOn.rawValue),
                data: [
                    "entity_id": light.entityId,
                    "brightness": brightness,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Set Light Color Intent

@available(iOS 18, *)
struct SetLightColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Light Color"
    static var isDiscoverable = false

    @Parameter(title: "Light")
    var light: IntentLightEntity

    @Parameter(title: "RGB Color")
    var rgbColor: [Int]

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: Service.turnOn.rawValue),
                data: [
                    "entity_id": light.entityId,
                    "rgb_color": rgbColor,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Set Light Color Temperature Intent

@available(iOS 18, *)
struct SetLightColorTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Light Color Temperature"
    static var isDiscoverable = false

    @Parameter(title: "Light")
    var light: IntentLightEntity

    @Parameter(title: "Color Temperature (mireds)")
    var colorTemp: Int

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: Service.turnOn.rawValue),
                data: [
                    "entity_id": light.entityId,
                    "color_temp": colorTemp,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Toggle Light Intent

@available(iOS 18, *)
struct ToggleLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Light"
    static var isDiscoverable = false

    @Parameter(title: "Light")
    var light: IntentLightEntity

    @Parameter(title: "Turn On")
    var turnOn: Bool

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let service = turnOn ? Service.turnOn.rawValue : Service.turnOff.rawValue

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": light.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}
