import AppKit

@main
class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    // Replaces the previous nib-based startup. The `@main` attribute would
    // normally synthesise `NSApplicationMain(argc, argv)`, which reads
    // `NSMainNibFile` from `Info.plist` and loads `Application.xib` to wire up
    // the delegate. With the nib removed, we provide `main()` explicitly and
    // hook the delegate up in code. `LSBackgroundOnly = true` means there is
    // no menu bar to configure.
    static func main() {
        let app = NSApplication.shared
        let delegate = LauncherAppDelegate()
        app.delegate = delegate
        app.run()
    }

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
            if let app {
                print("launched app: \(app)")
            } else if let error {
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
