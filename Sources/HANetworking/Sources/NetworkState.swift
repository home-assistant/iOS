import Foundation

/// A snapshot of the network information (Wi-Fi and interface details) available to the app.
///
/// Lives in HANetworking because `ConnectionInfo` evaluates it to decide internal-vs-external URL. The
/// concrete fetching (`ConnectivityWrapper`, CoreTelephony/NetworkExtension/macBridge) stays in HACore
/// and feeds values in through `HANetworkingEnvironment.connectivity`.
public struct NetworkState: Equatable {
    /// The SSID of the Wi-Fi network the device is currently connected to, if any.
    public var ssid: String?
    /// The BSSID of the Wi-Fi network the device is currently connected to, if any.
    public var bssid: String?
    /// The hardware (MAC) address of the active network interface, if available (macOS only).
    public var hardwareAddress: String?

    public init(ssid: String? = nil, bssid: String? = nil, hardwareAddress: String? = nil) {
        self.ssid = ssid
        self.bssid = bssid
        self.hardwareAddress = hardwareAddress
    }
}
