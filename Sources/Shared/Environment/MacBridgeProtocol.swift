import CoreGraphics
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
    func configureStatusItem(title: String)

    func setLoginItem(forBundleIdentifier: String, enabled: Bool) -> Bool
    func isLoginItemEnabled(forBundleIdentifier identifier: String) -> Bool
}

@objc(MacBridgeStatusItemCallbackInfo) public protocol MacBridgeStatusItemCallbackInfo {
    var isActive: Bool { get }
    func activate()
    func deactivate()
    func terminate()
}

// not actually possible to represent, via swift into objc and back into swift, the OptionSet import of this
@objc(MacBridgeStatusModifierMask) public enum MacBridgeStatusModifierMask: Int {
    case capsLock = 0b1 // Set if Caps Lock key is pressed.
    case shift = 0b10 // Set if Shift key is pressed.
    case control = 0b100 // Set if Control key is pressed.
    case option = 0b1000 // Set if Option or Alternate key is pressed.
    case command = 0b10000 // Set if Command key is pressed.
    case numericPad = 0b100000 // Set if any key in the numeric keypad is pressed.
    case help = 0b1000000 // Set if the Help key is pressed.
    case function = 0b1000_0000 // Set if any function key is pressed.
}

@objc(MacBridgeStatusItemActionInfo) public protocol MacBridgeStatusItemMenuItem {
    var name: String { get }
    var image: CGImage? { get }
    var imageSize: CGSize { get }
    var isSeparator: Bool { get }
    var keyEquivalentModifierMask: Int { get }
    var keyEquivalent: String { get }
    var subitems: [MacBridgeStatusItemMenuItem] { get }
    var primaryActionHandler: (MacBridgeStatusItemCallbackInfo) -> Void { get }
}

@objc(MacBridgeStatusItemConfiguration) public protocol MacBridgeStatusItemConfiguration {
    var isVisible: Bool { get }
    var image: CGImage { get }
    var imageSize: CGSize { get }
    var accessibilityLabel: String { get }
    var items: [MacBridgeStatusItemMenuItem] { get }
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
