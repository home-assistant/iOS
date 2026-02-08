import AppKit

@main
class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        let appIdentifier = String(bundleIdentifier[..<bundleIdentifier.lastIndex(of: ".")!])

        guard NSRunningApplication.runningApplications(withBundleIdentifier: appIdentifier).isEmpty else {
            didFinishLaunchingMainApp()
            return
        }

        // we're in HA.app/Contents/Library/LoginItems/Launcher.app, and we want to get our container app
        let appURL = Bundle.main.bundleURL.appendingPathComponent("../../../../").resolvingSymlinksInPath()

        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.activates = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfiguration) { [self] app, error in
            DispatchQueue.main.async { [self] in
                didFinishLaunchingMainApp()
            }
        }
    }

    func didFinishLaunchingMainApp() {
        precondition(Thread.isMainThread)
        NSApp.terminate(nil)
    }
}
