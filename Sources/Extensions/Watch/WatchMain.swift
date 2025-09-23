import Shared
import SwiftUI
import WatchKit

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
        WKNotificationScene(
            controller: DynamicNotificationHostingController.self,
            category: "DYNAMIC"
        )
    }
}
