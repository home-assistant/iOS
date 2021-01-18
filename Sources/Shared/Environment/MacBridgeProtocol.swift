import Foundation

// Must be @objc so we get the same reference in memory, since we're not directly loading the bundle
@objc(MacBridge) public protocol MacBridge: NSObjectProtocol {
    init()

    var distributedNotificationCenter: NotificationCenter { get }
    var workspaceNotificationCenter: NotificationCenter { get }

    var networkConnectivity: MacBridgeNetworkConnectivity { get }
    var networkConnectivityDidChangeNotification: Notification.Name { get }

    var terminationWillBeginNotification: Notification.Name { get }

    var screens: [MacBridgeScreen] { get }
    var screensWillChangeNotification: Notification.Name { get }

    var frontmostApplication: MacBridgeRunningApplication? { get }
    var frontmostApplicationDidChangeNotification: Notification.Name { get }

    var activationPolicy: MacBridgeActivationPolicy { get set }
    func configureStatusItem(using configuration: MacBridgeStatusItemConfiguration)

    func setLoginItem(forBundleIdentifier: String, enabled: Bool) -> Bool
    func isLoginItemEnabled(forBundleIdentifier identifier: String) -> Bool
}

@objc(MacBridgeStatusItemCallbackInfo) public protocol MacBridgeStatusItemCallbackInfo {
    var isActive: Bool { get }
    func activate()
    func deactivate()
}

@objc(MacBridgeStatusItemConfiguration) public protocol MacBridgeStatusItemConfiguration {
    var isVisible: Bool { get }
    var image: CGImage { get }
    var imageSize: CGSize { get }
    var accessibilityLabel: String { get }
    var primaryActionHandler: (MacBridgeStatusItemCallbackInfo) -> Void { get }
}

@objc(MacBridgeActivationPolicy) public enum MacBridgeActivationPolicy: Int {
    case regular
    case accessory
    case prohibited
}

@objc(MacBridgeNetworkType) public enum MacBridgeNetworkType: Int {
    case ethernet
    case wifi
    case noNetwork
    case unknown
}

@objc(MacBridgeNetworkConnectivity) public protocol MacBridgeNetworkConnectivity: NSObjectProtocol {
    var networkType: MacBridgeNetworkType { get }
    var hasWiFi: Bool { get }
    var wifi: MacBridgeWiFi? { get }
    var interface: MacBridgeNetworkInterface? { get }
}

@objc(MacBridgeNetworkInterface) public protocol MacBridgeNetworkInterface: NSObjectProtocol {
    var name: String { get }
    var hardwareAddress: String { get }
}

@objc(MacBridgeWiFiConnectivity) public protocol MacBridgeWiFi: NSObjectProtocol {
    var ssid: String { get }
    var bssid: String { get }
}

@objc(MacBridgeScreen) public protocol MacBridgeScreen: NSObjectProtocol {
    var identifier: String { get }
    var name: String { get }
}

@objc(MacBridgeRunningApplication) public protocol MacBridgeRunningApplication: NSObjectProtocol {
    var localizedName: String? { get }
    var bundleIdentifier: String? { get }
    var launchDate: Date? { get }
    var isHidden: Bool { get }
    var ownsMenuBar: Bool { get }
}
