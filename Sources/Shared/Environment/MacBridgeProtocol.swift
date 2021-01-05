import Foundation

// Must be @objc so we get the same reference in memory, since we're not directly loading the bundle
@objc(MacBridge) public protocol MacBridge: NSObjectProtocol {
    init()

    var distributedNotificationCenter: NotificationCenter { get }
    var workspaceNotificationCenter: NotificationCenter { get }

    var wifiConnectivity: MacBridgeWiFiConnectivity? { get }

    var terminationWillBeginNotification: Notification.Name { get }
}

@objc(MacBridgeWiFiConnectivity) public protocol MacBridgeWiFiConnectivity: NSObjectProtocol {
    var ssid: String? { get }
    var bssid: String? { get }
}
