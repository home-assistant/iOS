#if os(iOS) && !targetEnvironment(macCatalyst)
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import RoomPlan
@testable import Shared
import Testing

@Suite(.serialized)
struct SpatialScannerAPITests {
    @Test("Preflight requests the scanner contract and decodes its limit")
    func preflight() async throws {
        let previousServers = Current.servers
        let previousCachedApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousCachedApis
        }

        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        let server = try #require(servers.all.first)
        let api = FakeHomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        let task = Task {
            try await SpatialScannerAPI.preflight(server: server)
        }
        for _ in 0 ..< 10 {
            await Task.yield()
            if !connection.pendingRequests.isEmpty { break }
        }

        let pendingRequest = try #require(connection.pendingRequests.first)
        #expect(pendingRequest.request.type == "spatial_scanner/info")
        pendingRequest.completion(.success(.dictionary([
            "schema_version": 1,
            "max_payload_bytes": 4096,
        ])))

        let result = try await task.value
        #expect(result == 4096)
    }

    @Test("Upload acknowledgements decode into receipts")
    func decodesReceipt() throws {
        let receipt = try SpatialScannerAPI.receipt(from: .dictionary([
            "scan_id": "scan-123",
            "stored_at": "2026-07-29T12:00:00+00:00",
            "bytes": 42,
        ]))

        #expect(receipt == SpatialScanReceipt(
            scanID: "scan-123",
            storedAt: "2026-07-29T12:00:00+00:00",
            bytes: 42
        ))
    }

    @Test("Malformed upload acknowledgements are rejected")
    func rejectsMalformedReceipt() {
        #expect(throws: SpatialScannerAPI.Error.self) {
            try SpatialScannerAPI.receipt(from: .dictionary(["scan_id": "scan-123"]))
        }
    }

    @Test("Settings visibility follows RoomPlan LiDAR support")
    func hardwareGating() {
        #expect(SettingsItem.spatialScanner.isVisible == RoomCaptureSession.isSupported)
    }
}

private final class FakeHomeAssistantAPI: HomeAssistantAPI {}
#endif
