import Foundation

/// A device identifier together with the vendor identifier of the device that registered with it.
public struct RegistrationIdentity: Codable, Hashable {
    public var deviceID: String
    public var ownerVendorID: String?

    public init(deviceID: String, ownerVendorID: String?) {
        self.deviceID = deviceID
        self.ownerVendorID = ownerVendorID
    }
}
