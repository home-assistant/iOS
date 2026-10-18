import Foundation

/// What a `mobile_app` registration is made with: the identifier Home Assistant knows the device by, which makes a
/// registration under one it already has replace that registration rather than add a device, and the device the
/// registration belongs to.
public struct RegistrationIdentity: Codable, Equatable {
    public var deviceID: String
    /// The vendor identifier of the device the registration belongs to, when there was one to record.
    public var ownerVendorID: String?

    public init(deviceID: String, ownerVendorID: String?) {
        self.deviceID = deviceID
        self.ownerVendorID = ownerVendorID
    }
}
