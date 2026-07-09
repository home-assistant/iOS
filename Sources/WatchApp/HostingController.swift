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
        }
    }
}

// Retained so the legacy `Interface.storyboard` reference resolves; unused under the SwiftUI lifecycle.
final class HostingController: WKHostingController<WatchHomeView> {
    override var body: WatchHomeView {
        WatchHomeView()
    }
}
