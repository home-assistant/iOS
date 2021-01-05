import Foundation
import AppKit
import CoreWLAN

@objc(HAMacBridgeImpl) final class MacBridgeImpl: NSObject, MacBridge {
    let wifiClient: CWWiFiClient

    override init() {
        self.wifiClient = CWWiFiClient.shared()

        super.init()

        MacBridgeAppDelegateHandler.swizzleAppDelegate()
    }

    var terminationWillBeginNotification: Notification.Name {
        MacBridgeAppDelegateHandler.terminationWillBeginNotification
    }

    var distributedNotificationCenter: NotificationCenter {
        DistributedNotificationCenter.default()
    }

    var workspaceNotificationCenter: NotificationCenter {
        NSWorkspace.shared.notificationCenter
    }

    var wifiConnectivity: MacBridgeWiFiConnectivity? {
        if let interface = wifiClient.interfaces()?.first {
            return MacBridgeWiFiConnectivityImpl(ssid: interface.ssid(), bssid: interface.bssid())
        } else {
            return nil
        }
    }
}
