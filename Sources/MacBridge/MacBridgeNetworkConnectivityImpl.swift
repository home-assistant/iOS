import Foundation

@objc final class MacBridgeNetworkConnectivityImpl: NSObject, MacBridgeNetworkConnectivity {
    let networkType: MacBridgeNetworkType
    let hasWiFi: Bool
    let wifi: MacBridgeWiFi?
    let interface: MacBridgeNetworkInterface?

    init(
        networkType: MacBridgeNetworkType,
        hasWiFi: Bool,
        wifi: MacBridgeWiFi?,
        interface: MacBridgeNetworkInterface?
    ) {
        self.networkType = networkType
        self.wifi = wifi
        self.hasWiFi = hasWiFi
        self.interface = interface
    }
}

@objc final class MacBridgeWiFiImpl: NSObject, MacBridgeWiFi {
    let ssid: String
    let bssid: String

    init(ssid: String, bssid: String) {
        self.ssid = ssid
        self.bssid = bssid
    }
}

@objc final class MacBridgeNetworkInterfaceImpl: NSObject, MacBridgeNetworkInterface {
    let name: String
    let hardwareAddress: String

    init(name: String, hardwareAddress: String) {
        self.name = name
        self.hardwareAddress = hardwareAddress.lowercased()
    }
}
