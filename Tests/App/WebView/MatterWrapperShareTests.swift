import HomeKit
@testable import Shared
import XCTest

final class MatterWrapperShareTests: XCTestCase {
    // The CHIP SDK's example QR code; the values below are what it decodes to.
    private static let qrCode = "MT:-24J0AFN00KA0648G00"

    private let fieldsPayload: [String: Any] = [
        "setup_qr_code": MatterWrapperShareTests.qrCode,
        "setup_pin_code": 20_202_021,
        "discriminator": 3840,
        "vendor_id": 0xFFF1,
        "product_id": 0x8001,
        "device_name": "Kitchen light",
    ]

    func testShareRequestPrefersTheValues() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: fieldsPayload))

        XCTAssertEqual(
            request.window,
            .values(passcode: 20_202_021, discriminator: 3840, vendorID: 0xFFF1, productID: 0x8001)
        )
        XCTAssertEqual(request.deviceName, "Kitchen light")
    }

    /// JavaScript delivers every number as a double.
    func testShareRequestReadsTheValuesAsJavaScriptDeliversThem() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: [
            "setup_qr_code": Self.qrCode,
            "setup_pin_code": NSNumber(value: 20_202_021 as Double),
            "discriminator": NSNumber(value: 3840 as Double),
            "vendor_id": NSNumber(value: 65521 as Double),
            "product_id": NSNumber(value: 32769 as Double),
        ]))

        XCTAssertEqual(
            request.window,
            .values(passcode: 20_202_021, discriminator: 3840, vendorID: 0xFFF1, productID: 0x8001)
        )
    }

    func testShareRequestFallsBackWhenEitherValueIsMissing() throws {
        for missing in ["setup_pin_code", "discriminator"] {
            var payload = fieldsPayload
            payload[missing] = nil

            XCTAssertEqual(
                try XCTUnwrap(MatterShareRequest(payload: payload)).window,
                .setupCode(Self.qrCode),
                "a window without \(missing) has to take the setup code"
            )
        }
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

    /// The server is trusted, so nothing checks the Matter specification.
    func testValuesTheSpecificationForbidsAreStillUsed() throws {
        var payload = fieldsPayload
        payload["setup_pin_code"] = 12_345_678
        payload["discriminator"] = 4096

        XCTAssertEqual(
            try XCTUnwrap(MatterShareRequest(payload: payload)).window,
            .values(passcode: 12_345_678, discriminator: 4096, vendorID: 0xFFF1, productID: 0x8001)
        )
    }

    func testValuesThatDoNotFitTheirTypeFallBackToTheSetupCode() throws {
        for (key, value) in [
            ("discriminator", 70000),
            ("setup_pin_code", -1),
            ("discriminator", NSNumber(value: 3840.5)),
        ] as [(String, Any)] {
            var payload = fieldsPayload
            payload[key] = value

            XCTAssertEqual(
                try XCTUnwrap(MatterShareRequest(payload: payload)).window,
                .setupCode(Self.qrCode),
                "\(key) = \(value) has to take the setup code"
            )
        }
    }

    /// Vendor and product only name the device, so one that does not fit costs only itself, not the window.
    func testIdentifiersThatDoNotFitAreLeftOut() throws {
        var payload = fieldsPayload
        payload["vendor_id"] = 0x10000
        payload["product_id"] = 0x10000

        XCTAssertEqual(
            try XCTUnwrap(MatterShareRequest(payload: payload)).window,
            .values(passcode: 20_202_021, discriminator: 3840, vendorID: nil, productID: nil)
        )
    }

    func testShareRequestRejectsPayloadsWithNeither() {
        XCTAssertNil(MatterShareRequest(payload: nil))
        XCTAssertNil(MatterShareRequest(payload: ["setup_pin_code": 20_202_021]))
        XCTAssertNil(MatterShareRequest(payload: ["setup_pin_code": 20_202_021, "discriminator": 70000]))
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
        XCTAssertEqual(payload.productID, 0x8001)
        XCTAssertEqual(payload.discoveryCapabilities, .onNetwork)
        XCTAssertNotNil(payload.manualEntryCode())
    }

    func testSetupPayloadFromTheSetupCode() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": Self.qrCode]))

        let payload = try XCTUnwrap(MatterWrapper.setupPayload(for: request))

        XCTAssertEqual(payload.setupPasscode, 20_202_021)
        XCTAssertEqual(payload.discriminator, 3840)
        XCTAssertEqual(payload.vendorID, 0xFFF1)
        XCTAssertEqual(payload.productID, 0x8001)
    }

    /// A HomeKit payload would need another entitlement and is never set.
    func testAccessorySetupRequestCarriesThePayloadAndTheName() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: fieldsPayload))

        let setupRequest = try XCTUnwrap(MatterWrapper.accessorySetupRequest(for: request))

        XCTAssertEqual(setupRequest.matterPayload?.setupPasscode, 20_202_021)
        XCTAssertEqual(setupRequest.matterPayload?.discriminator, 3840)
        XCTAssertEqual(setupRequest.suggestedAccessoryName, "Kitchen light")
        XCTAssertNil(setupRequest.payload)
        XCTAssertNil(setupRequest.homeUniqueIdentifier)
        XCTAssertNil(setupRequest.suggestedRoomUniqueIdentifier)

        // Without a name the home app suggests its own.
        let nameless = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": Self.qrCode]))

        XCTAssertNil(try XCTUnwrap(MatterWrapper.accessorySetupRequest(for: nameless)).suggestedAccessoryName)
    }

    func testAccessorySetupRequestIsNilWhenTheWindowHasNoPayload() throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": "not a setup code"]))

        XCTAssertNil(MatterWrapper.accessorySetupRequest(for: request))
    }

    /// A real server window for a test light.
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
        // Shows the forced `.onNetwork` matches a real window; it cannot tell which path sets it.
        XCTAssertEqual(fromValues.discoveryCapabilities, fromSetupCode.discoveryCapabilities)
        XCTAssertEqual(fromValues.commissioningFlow, fromSetupCode.commissioningFlow)
        XCTAssertEqual(fromValues.version, fromSetupCode.version)
        XCTAssertEqual(fromValues.manualEntryCode(), fromSetupCode.manualEntryCode())
    }

    func testShareErrorFailed() {
        XCTAssertEqual(MatterWrapper.shareError(for: HMError(.communicationFailure)).code, "failed")
        XCTAssertEqual(MatterWrapper.shareError(for: MatterShareError.invalidRequest).code, "failed")

        let unsupported = MatterWrapper.shareError(for: MatterShareError.unsupported)

        XCTAssertEqual(unsupported.code, "failed")
        XCTAssertTrue(unsupported.message.contains("not supported"))
    }

    /// The one part of the real implementation a test can reach without HomeKit.
    @MainActor func testShareDeviceRejectsAWindowWithoutAPayload() async throws {
        let request = try XCTUnwrap(MatterShareRequest(payload: ["setup_qr_code": "not a setup code"]))

        do {
            try await MatterWrapper().shareDevice(request)
            XCTFail("a window without a payload must not reach HomeKit")
        } catch {
            XCTAssertEqual(error as? MatterShareError, .invalidRequest)
        }
    }

    /// The wording is not contract, but it must not depend on the device's language.
    func testShareErrorMessageIsDeterministicDiagnosis() {
        let message = MatterWrapper.shareError(for: HMError(.communicationFailure)).message

        XCTAssertTrue(message.contains("HMErrorDomain"))
        XCTAssertFalse(message.contains(HMError(.communicationFailure).localizedDescription))
    }

    func testResultErrorCarriesTheContractsCodes() {
        XCTAssertEqual(WebSocketMessage.ResultError.canceled("x").code, "canceled")
        XCTAssertEqual(WebSocketMessage.ResultError.failed("x").message, "x")
        XCTAssertFalse(WebSocketMessage.ResultError.failed("x").isCanceled)
    }

    func testShareErrorCancelledIsNotAFailure() {
        let cancelled = MatterWrapper.shareError(for: HMError(.operationCancelled))

        XCTAssertEqual(cancelled.code, "canceled")
        XCTAssertTrue(cancelled.isCanceled)
        XCTAssertFalse(MatterWrapper.shareError(for: HMError(.communicationFailure)).isCanceled)
    }
}
