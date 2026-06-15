// Native macOS app entry point (target: App-macOS).
//
// SwiftUI lifecycle entry for the native macOS build. The iOS target keeps its
// UIKit `@main AppDelegate`; this file is only a member of App-macOS, and the
// `#if os(macOS)` guard makes it inert if ever compiled elsewhere.
//
// As `Shared` becomes available on macOS, `MacAppDelegate` takes on the shared
// bootstrap the UIKit AppDelegate performs on iOS (servers, sensors, push, …).

#if os(macOS)
import AppKit
import SwiftUI

@main
struct MacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MacRootView()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {} // single frontend window
        }
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
