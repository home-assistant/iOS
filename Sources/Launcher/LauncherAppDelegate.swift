import AppKit

@main
class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        let appIdentifier = String(bundleIdentifier[..<bundleIdentifier.lastIndex(of: ".")!])
        Current.Log.verbose("launcher identifier: \(bundleIdentifier)")
        Current.Log.verbose("app identifier: \(appIdentifier)")
        Current.Log.verbose("running from \(Bundle.main.bundlePath)")

        guard NSRunningApplication.runningApplications(withBundleIdentifier: appIdentifier).isEmpty else {
            Current.Log.verbose("app already launching, not doing anything")
            didFinishLaunchingMainApp()
            return
        }

        // we're in HA.app/Contents/Library/LoginItems/Launcher.app, and we want to get our container app
        let appURL = Bundle.main.bundleURL.appendingPathComponent("../../../../").resolvingSymlinksInPath()
        Current.Log.verbose("launching app at \(appURL.path)")

        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.activates = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfiguration) { [self] app, error in
            if let app {
                Current.Log.verbose("launched app: \(app)")
            } else if let error {
                Current.Log.verbose("failed to launch app: \(error)")
            }

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
