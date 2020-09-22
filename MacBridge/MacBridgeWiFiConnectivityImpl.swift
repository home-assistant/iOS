import Foundation

@objc class MacBridgeWiFiConnectivityImpl: NSObject, MacBridgeWiFiConnectivity {
    let ssid: String?
    let bssid: String?

    init(ssid: String?, bssid: String?) {
        self.ssid = ssid
        self.bssid = bssid
    }
}
