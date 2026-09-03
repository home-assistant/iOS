import Foundation

public extension ServerInfo {
    /// The `device_name` this app's `mobile_app` registration with the server carries — the name the
    /// integration shows in Home Assistant: the user's override for the server, else the device's own
    /// name.
    var mobileAppDeviceName: String {
        setting(for: .overrideDeviceName) ?? Current.device.deviceName()
    }
}
