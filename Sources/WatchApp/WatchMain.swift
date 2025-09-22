import Shared
import SwiftUI
import UserNotifications
import WatchKit
import MapKit

@main
struct WatchMain: App {
    @WKApplicationDelegateAdaptor private var extensionDelegate: ExtensionDelegate

    init() {
        MaterialDesignIcons.register()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        WKNotificationScene(controller: DynamicNotificationScene.self, category: "DYNAMIC")
    }
}

