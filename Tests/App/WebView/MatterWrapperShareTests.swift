import HomeKit
@testable import Shared
import XCTest

final class MatterWrapperShareTests: XCTestCase {
    // The CHIP SDK's example QR code: passcode 20202021, discriminator 3840.
    private static let qrCode = "MT:-24J0AFN00KA0648G00"

    private let fieldsPayload: [String: Any] = [
        "setup_qr_code": MatterWrapperShareTests.qrCode,
        "setup_pin_code": 20_202_021,
        "discriminator": 3840,
        "vendor_id": 0xFFF1,
        "product_id": 0x8000,
        "device_name": "Kitchen light",
    ]

    func testShareRequestPrefersTheValues() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: fieldsPayload))

        XCTAssertEqual(
            request.window,
            .values(passcode: 20_202_021, discriminator: 3840, vendorID: 0xFFF1, productID: 0x8000)
        )
        XCTAssertEqual(request.deviceName, "Kitchen light")
    }

    func testShareRequestFallsBackToTheSetupCode() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: [
            "setup_qr_code": Self.qrCode,
            "setup_pin_code": NSNumber(value: 20_202_021),
            "device_name": "",
        ]))

        XCTAssertEqual(request.window, .setupCode(Self.qrCode))
        XCTAssertNil(request.deviceName)
    }

    func testInvalidValuesFallBackToTheSetupCode() throws {
        var payload = fieldsPayload
        payload["discriminator"] = 4096

        XCTAssertEqual(try XCTUnwrap(MatterShareRequest(payload: payload)).window, .setupCode(Self.qrCode))
    }

    func testForbiddenPasscodeFallsBackToTheSetupCode() throws {
        var payload = fieldsPayload
        payload["setup_pin_code"] = 12_345_678

        XCTAssertEqual(try XCTUnwrap(MatterShareRequest(payload: payload)).window, .setupCode(Self.qrCode))
    }

    func testShareRequestRejectsPayloadsWithNeither() {
        XCTAssertNil(MatterShareRequest(payload: nil))
        XCTAssertNil(MatterShareRequest(payload: ["setup_pin_code": 20_202_021]))
        XCTAssertNil(MatterShareRequest(payload: ["setup_pin_code": 20_202_021, "discriminator": 4096]))
        XCTAssertNil(MatterShareRequest(payload: ["setup_pin_code": 12_345_678, "discriminator": 3840]))
        XCTAssertNil(MatterShareRequest(payload: ["setup_qr_code": ""]))
        XCTAssertNil(MatterShareRequest(payload: ["setup_qr_code": 42]))
    }

    func testSetupPayloadFromTheValues() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: fieldsPayload))

        let payload = try XCTUnwrap(MatterWrapper.setupPayload(for: request))

        XCTAssertEqual(payload.setupPasscode, 20_202_021)
        XCTAssertEqual(payload.discriminator, 3840)
        XCTAssertFalse(payload.hasShortDiscriminator)
        XCTAssertEqual(payload.vendorID, 0xFFF1)
        XCTAssertEqual(payload.productID, 0x8000)
        XCTAssertEqual(payload.discoveryCapabilities, .onNetwork)
        XCTAssertNotNil(payload.manualEntryCode())
    }

    func testSetupPayloadFromTheSetupCode() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": Self.qrCode]))

        let payload = try XCTUnwrap(MatterWrapper.setupPayload(for: request))

        XCTAssertEqual(payload.setupPasscode, 20_202_021)
        XCTAssertEqual(payload.discriminator, 3840)
    }

    /// Both paths have to hand HomeKit the same payload. The window is what a Matter server returned through
    /// Home Assistant's `matter/open_commissioning_window` for a test light.
    func testSetupPayloadFromTheValuesMatchesTheServersSetupCode() throws {
        let serverWindow: [String: Any] = [
            "setup_pin_code": 9_682_341,
            "setup_qr_code": "MT:Y.K90C0R154U9X3T700",
            "discriminator": 3621,
            "vendor_id": 65521,
            "product_id": 32768,
        ]
        let fromValues = try XCTUnwrap(MatterWrapper.setupPayload(
            for: XCTUnwrap(MatterShareRequest(payload: serverWindow))
        ))
        let fromSetupCode = try XCTUnwrap(MatterWrapper.setupPayload(
            for: XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": serverWindow["setup_qr_code"]!]))
        ))

        XCTAssertEqual(fromValues.setupPasscode, fromSetupCode.setupPasscode)
        XCTAssertEqual(fromValues.discriminator, fromSetupCode.discriminator)
        XCTAssertEqual(fromValues.hasShortDiscriminator, fromSetupCode.hasShortDiscriminator)
        XCTAssertEqual(fromValues.vendorID, fromSetupCode.vendorID)
        XCTAssertEqual(fromValues.productID, fromSetupCode.productID)
        XCTAssertEqual(fromValues.discoveryCapabilities, fromSetupCode.discoveryCapabilities)
        XCTAssertEqual(fromValues.commissioningFlow, fromSetupCode.commissioningFlow)
        XCTAssertEqual(fromValues.version, fromSetupCode.version)
        XCTAssertEqual(fromValues.manualEntryCode(), fromSetupCode.manualEntryCode())
    }

    func testSetupPayloadFromAnUnparsableSetupCodeIsNil() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": "not a setup code"]))

        XCTAssertNil(MatterWrapper.setupPayload(for: request))
    }

    func testShareErrorCodeCancelled() {
        XCTAssertEqual(MatterWrapper.shareErrorCode(for: HMError(.operationCancelled)), "cancelled")
    }

    func testShareErrorCodeFailed() {
        XCTAssertEqual(MatterWrapper.shareErrorCode(for: HMError(.communicationFailure)), "failed")
        XCTAssertEqual(MatterWrapper.shareErrorCode(for: MatterShareError.invalidRequest), "failed")
    }
}
