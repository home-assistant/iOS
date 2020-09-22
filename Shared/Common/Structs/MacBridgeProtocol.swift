import Foundation

// Must be @objc so we get the same reference in memory, since we're not directly loading the bundle
@objc(MacBridge) public protocol MacBridge: NSObjectProtocol {
    init()

    var distributedNotificationCenter: NotificationCenter { get }
    var workspaceNotificationCenter: NotificationCenter { get }
}
