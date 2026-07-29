#if os(iOS) && !targetEnvironment(macCatalyst)
import HAKit
@testable import HomeAssistant
import RoomPlan
import Testing

struct SpatialScannerAPITests {
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
#endif
