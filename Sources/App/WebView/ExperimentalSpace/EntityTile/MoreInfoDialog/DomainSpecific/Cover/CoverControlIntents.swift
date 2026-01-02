import AppIntents
import Foundation
import HAKit
import Shared

// MARK: - Set Cover Position Intent

@available(iOS 18, *)
struct SetCoverPositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Cover Position"
    static var isDiscoverable = false

    @Parameter(title: "Cover")
    var cover: IntentCoverEntity

    @Parameter(title: "Position")
    var position: Int

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == cover.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: "cover"),
                service: .init(stringLiteral: "set_cover_position"),
                data: [
                    "entity_id": cover.entityId,
                    "position": position,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Open Cover Intent

@available(iOS 18, *)
struct OpenCoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Cover"
    static var isDiscoverable = false

    @Parameter(title: "Cover")
    var cover: IntentCoverEntity

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == cover.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: "cover"),
                service: .init(stringLiteral: "open_cover"),
                data: [
                    "entity_id": cover.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Close Cover Intent

@available(iOS 18, *)
struct CloseCoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Cover"
    static var isDiscoverable = false

    @Parameter(title: "Cover")
    var cover: IntentCoverEntity

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == cover.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: "cover"),
                service: .init(stringLiteral: "close_cover"),
                data: [
                    "entity_id": cover.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Stop Cover Intent

@available(iOS 18, *)
struct StopCoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Cover"
    static var isDiscoverable = false

    @Parameter(title: "Cover")
    var cover: IntentCoverEntity

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == cover.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: "cover"),
                service: .init(stringLiteral: "stop_cover"),
                data: [
                    "entity_id": cover.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}

// MARK: - Set Cover Tilt Position Intent

@available(iOS 18, *)
struct SetCoverTiltPositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Cover Tilt Position"
    static var isDiscoverable = false

    @Parameter(title: "Cover")
    var cover: IntentCoverEntity

    @Parameter(title: "Tilt Position")
    var tiltPosition: Int

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == cover.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: "cover"),
                service: .init(stringLiteral: "set_cover_tilt_position"),
                data: [
                    "entity_id": cover.entityId,
                    "tilt_position": tiltPosition,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}
