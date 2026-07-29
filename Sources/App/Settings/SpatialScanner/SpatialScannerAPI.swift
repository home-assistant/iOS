#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HAKit
import Shared

enum SpatialScannerAPI {
    enum Error: Swift.Error {
        case invalidPayload
        case invalidResponse
        case noAPI
        case payloadTooLarge
    }

    static func preflight(server: Server) async throws -> Int {
        let data = try await send(
            request: .init(type: "spatial_scanner/info"),
            server: server
        )
        guard case let .dictionary(response) = data,
              let schemaVersion = response["schema_version"] as? Int,
              schemaVersion == 1,
              let maxPayloadBytes = response["max_payload_bytes"] as? Int else {
            throw Error.invalidResponse
        }
        return maxPayloadBytes
    }

    static func upload(
        payload: SpatialScanPayload,
        maxPayloadBytes: Int,
        server: Server
    ) async throws -> SpatialScanReceipt {
        let payloadObject = try payload.jsonObject()
        let encoded = try JSONSerialization.data(withJSONObject: payloadObject)
        guard encoded.count <= maxPayloadBytes else {
            throw Error.payloadTooLarge
        }

        let data = try await send(
            request: .init(
                type: "spatial_scanner/upload",
                data: ["payload": payloadObject]
            ),
            server: server
        )
        return try receipt(from: data)
    }

    static func receipt(from data: HAData) throws -> SpatialScanReceipt {
        guard case let .dictionary(response) = data,
              let scanID = response["scan_id"] as? String,
              let storedAt = response["stored_at"] as? String,
              let bytes = response["bytes"] as? Int else {
            throw Error.invalidResponse
        }
        return SpatialScanReceipt(scanID: scanID, storedAt: storedAt, bytes: bytes)
    }

    private static func send(request: HARequest, server: Server) async throws -> HAData {
        guard let api = Current.api(for: server) else {
            throw Error.noAPI
        }
        return try await withCheckedThrowingContinuation { continuation in
            api.connection.send(request) { result in
                continuation.resume(with: result)
            }
        }
    }
}
#endif
