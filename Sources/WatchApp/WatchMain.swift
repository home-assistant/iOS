import Shared
import SwiftUI

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
    }
}
