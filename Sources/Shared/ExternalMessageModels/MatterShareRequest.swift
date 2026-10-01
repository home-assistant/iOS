import Foundation

/// `remaining_seconds` is not read: HomeKit takes no window duration.
public struct MatterShareRequest: Equatable, Sendable {
    /// Older Matter servers send only the setup code.
    public enum Window: Equatable, Sendable {
        case values(passcode: UInt32, discriminator: UInt16, vendorID: UInt16?, productID: UInt16?)
        case setupCode(String)
    }

    public let window: Window
    public let deviceName: String?

    /// The server's values are trusted. A passcode or discriminator that does not fit its type falls back to
    /// the setup code; a vendor or product ID that does not fit is dropped.
    public init?(payload: [String: Any]?) {
        guard let payload else {
            return nil
        }
        if let passcode = (payload["setup_pin_code"] as? NSNumber).flatMap({ UInt32(exactly: $0) }),
           let discriminator = (payload["discriminator"] as? NSNumber).flatMap({ UInt16(exactly: $0) }) {
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
