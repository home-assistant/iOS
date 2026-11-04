import Foundation

public extension ServerInfo {
    /// The `device_name` this app registers with the server: the override, else the device's name.
    var mobileAppDeviceName: String {
        setting(for: .overrideDeviceName) ?? Current.device.deviceName()
    }
}
