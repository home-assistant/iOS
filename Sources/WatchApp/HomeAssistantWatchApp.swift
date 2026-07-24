import Foundation
import Shared
import SwiftUI

// The watch app uses the SwiftUI App lifecycle so SwiftUI can deliver external events (URLs /
// NSUserActivity) — notably the `homeassistant://assist` widget URL from the Assist complication.
// The legacy WatchKit lifecycle (WKApplicationDelegate + WKHostingController) cannot receive those,
// hence the "Cannot use Scene methods for URL … without using SwiftUI Lifecycle" runtime warning.
@main
struct HomeAssistantWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var delegate

    init() {
        MaterialDesignIcons.register()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                // Toggles (and other tinted controls) render in the brand color app-wide;
                // watchOS has no UISwitch appearance proxy, so the tint cascades from the root.
                .tint(.haPrimary)
        }

        // Every category the server can send renders the same dynamic interface; both casings
        // exist in the wild (the docs historically suggested uppercase, the app lowercase).
        WKNotificationScene(controller: DynamicNotificationHostingController.self, category: "DYNAMIC")
        WKNotificationScene(controller: DynamicNotificationHostingController.self, category: "CAMERA")
        WKNotificationScene(controller: DynamicNotificationHostingController.self, category: "camera")
        WKNotificationScene(controller: DynamicNotificationHostingController.self, category: "MAP")
        WKNotificationScene(controller: DynamicNotificationHostingController.self, category: "map")
    }
}
