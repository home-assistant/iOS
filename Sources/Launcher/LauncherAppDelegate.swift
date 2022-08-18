import AppKit

@main
class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        let appIdentifier = String(bundleIdentifier[..<bundleIdentifier.lastIndex(of: ".")!])
        print("launcher identifier: \(bundleIdentifier)")
        print("app identifier: \(appIdentifier)")
        print("running from \(Bundle.main.bundlePath)")

        guard NSRunningApplication.runningApplications(withBundleIdentifier: appIdentifier).isEmpty else {
            print("app already launching, not doing anything")
            didFinishLaunchingMainApp()
            return
        }

        // we're in HA.app/Contents/Library/LoginItems/Launcher.app, and we want to get our container app
        let appURL = Bundle.main.bundleURL.appendingPathComponent("../../../../").resolvingSymlinksInPath()
        print("launching app at \(appURL.path)")

        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.activates = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfiguration) { [self] app, error in
            if let app = app {
                print("launched app: \(app)")
            } else if let error = error {
                print("failed to launch app: \(error)")
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
