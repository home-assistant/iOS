import Foundation
import AppKit

@objc(HAMacBridgeImpl) final class MacBridgeImpl: NSObject, MacBridge {
    override init() {
        super.init()
    }

    var distributedNotificationCenter: NotificationCenter {
        DistributedNotificationCenter.default()
    }

    var workspaceNotificationCenter: NotificationCenter {
        NSWorkspace.shared.notificationCenter
    }
}
