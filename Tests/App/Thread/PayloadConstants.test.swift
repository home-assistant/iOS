@testable import HomeAssistant
import Testing

struct PayloadConstants_test {
    @Test func validateWebViewMessageHandlerPayloadConstants() async throws {
        #expect(
            PayloadConstants.macExtendedAddress.rawValue == "mac_extended_address",
            "Wrong value for macExtendedAddress"
        )
        #expect(PayloadConstants.extendedPanId.rawValue == "extended_pan_id", "Wrong value for extendedPanId")
        #expect(
            PayloadConstants.activeOperationalDataset.rawValue == "active_operational_dataset",
            "Wrong value for activeOperationalDataset"
        )
    }
}
