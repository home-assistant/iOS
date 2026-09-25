import Foundation

/// A commissioning window Home Assistant opened for one of its Matter devices, as the frontend sends it with
/// `matter/share_device`. `remaining_seconds` is not read: HomeKit takes no window duration, and the frontend
/// does not send an expired window.
public struct MatterShareRequest: Equatable {
    /// How the window is described. Newer Matter servers report its values; older ones only the setup code they
    /// are encoded in, which is always sent as well.
    public enum Window: Equatable {
        case values(passcode: UInt32, discriminator: UInt16, vendorID: UInt16?, productID: UInt16?)
        case setupCode(String)
    }

    /// Passcodes the Matter spec forbids besides the out-of-range ones (Core spec 5.1.7.1).
    private static let invalidPasscodes: Set<UInt32> = [
        11_111_111, 22_222_222, 33_333_333, 44_444_444, 55_555_555,
        66_666_666, 77_777_777, 88_888_888, 12_345_678, 87_654_321,
    ]
    private static let passcodeRange: ClosedRange<UInt32> = 1 ... 99_999_998
    private static let discriminatorRange: ClosedRange<UInt16> = 0 ... 0xFFF

    public let window: Window
    /// Home Assistant's name for the device, suggested to the home app.
    public let deviceName: String?

    public init?(payload: [String: Any]?) {
        guard let payload else {
            return nil
        }
        if let passcode = (payload["setup_pin_code"] as? NSNumber).flatMap({ UInt32(exactly: $0) }),
           Self.passcodeRange.contains(passcode), !Self.invalidPasscodes.contains(passcode),
           let discriminator = (payload["discriminator"] as? NSNumber).flatMap({ UInt16(exactly: $0) }),
           Self.discriminatorRange.contains(discriminator) {
            self.window = .values(
                passcode: passcode,
                discriminator: discriminator,
                vendorID: (payload["vendor_id"] as? NSNumber).flatMap { UInt16(exactly: $0) },
                productID: (payload["product_id"] as? NSNumber).flatMap { UInt16(exactly: $0) }
            )
        } else if let setupCode = payload["setup_qr_code"] as? String, !setupCode.isEmpty {
            self.window = .setupCode(setupCode)
        } else {
            return nil
        }
        self.deviceName = (payload["device_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
