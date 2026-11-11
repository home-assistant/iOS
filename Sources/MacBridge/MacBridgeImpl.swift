import AppKit
import Foundation
import ServiceManagement
import SystemConfiguration

@objc(HAMacBridgeImpl) final class MacBridgeImpl: NSObject, MacBridge {
    let networkMonitor: MacBridgeNetworkMonitor
    let statusItem: MacBridgeStatusItem?
    private var requestedActivationPolicy: MacBridgeActivationPolicy?

    override init() {
        if Bundle.main.isRunningInExtension {
            // status item can't talk to the status bar in an extension or it will crash
            self.statusItem = nil
        } else {
            self.statusItem = MacBridgeStatusItem()
        }

        self.networkMonitor = MacBridgeNetworkMonitor()

        super.init()

        MacBridgeAppDelegateHandler.swizzleAppDelegate()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyRequestedActivationPolicy),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        for name: Notification.Name in [
            NSApplication.didFinishLaunchingNotification,
            NSApplication.didFinishRestoringWindowsNotification,
            NSWindow.didBecomeKeyNotification,
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(fixWindows), name: name, object: nil)
        }
    }

    var deviceName: String {
        SCDynamicStoreCopyComputerName(nil, nil) as? String ?? "Unknown"
    }

    var terminationWillBeginNotification: Notification.Name {
        MacBridgeAppDelegateHandler.terminationWillBeginNotification
    }

    var distributedNotificationCenter: NotificationCenter {
        DistributedNotificationCenter.default()
    }

    var workspaceNotificationCenter: NotificationCenter {
        NSWorkspace.shared.notificationCenter
    }

    var networkConnectivity: MacBridgeNetworkConnectivity {
        networkMonitor.networkConnectivity
    }

    var networkConnectivityDidChangeNotification: Notification.Name {
        MacBridgeNetworkMonitor.connectivityDidChangeNotification
    }

    var screens: [MacBridgeScreen] {
        NSScreen.screens.map(MacBridgeScreenImpl.init(screen:))
    }

    var screensWillChangeNotification: Notification.Name {
        NSApplication.didChangeScreenParametersNotification
    }

    var frontmostApplication: MacBridgeRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    var frontmostApplicationDidChangeNotification: Notification.Name {
        NSWorkspace.didActivateApplicationNotification
    }

    var activationPolicy: MacBridgeActivationPolicy {
        get {
            switch NSApplication.shared.activationPolicy() {
            case .regular: return .regular
            case .accessory: return .accessory
            case .prohibited: return .prohibited
            @unknown default: return .regular
            }
        }
        set {
            requestedActivationPolicy = newValue
            // Catalyst uses .prohibited while handling a background launch. Promoting it to .regular
            // creates a window, even without activate(). Wait until the user opens the app.
            guard activationPolicy != .prohibited else { return }
            applyRequestedActivationPolicy()
        }
    }

    @objc private func applyRequestedActivationPolicy() {
        guard let requestedActivationPolicy, requestedActivationPolicy != activationPolicy else { return }
        let wasActive = NSApplication.shared.isActive
        NSApplication.shared.setActivationPolicy({
            switch requestedActivationPolicy {
            case .regular: return .regular
            case .accessory: return .accessory
            case .prohibited: return .prohibited
            }
        }())
        if wasActive {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func activateApp() {
        applyRequestedActivationPolicy()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func setReopenHandler(_ handler: @escaping () -> Bool) {
        MacBridgeAppDelegateHandler.reopenHandler = { [weak self] in
            let handled = handler()
            if !handled {
                self?.applyRequestedActivationPolicy()
            }
            return handled
        }
    }

    func configureStatusItem(using configuration: MacBridgeStatusItemConfiguration) {
        statusItem?.configure(using: configuration)
    }

    func configureStatusItem(title: String) {
        statusItem?.configure(title: title)
    }

    private static func userDefaultsKey(forLoginItemBundleIdentifier identifier: String) -> String {
        "LoginItemEnabled-\(identifier)"
    }

    func setLoginItem(forBundleIdentifier identifier: String, enabled: Bool) -> Bool {
        let success = SMLoginItemSetEnabled(identifier as CFString, enabled)
        if success {
            UserDefaults.standard.set(enabled, forKey: Self.userDefaultsKey(forLoginItemBundleIdentifier: identifier))
        }
        return success
    }

    func isLoginItemEnabled(forBundleIdentifier identifier: String) -> Bool {
        // TODO: SMJobIsEnabled is the Apple-suggested method of getting this info, and it's also private API. lol.
        UserDefaults.standard.bool(forKey: Self.userDefaultsKey(forLoginItemBundleIdentifier: identifier))
    }

    @objc private func fixWindows() {
        // macOS 13 when using Xcode 14 breaks our window display, see: https://developer.apple.com/forums/thread/716623
        guard #available(macOS 13, *) else { return }
        for window in NSApplication.shared.windows {
            if window.toolbar == nil || window.toolbar?.items.isEmpty == true {
                window.titlebarAppearsTransparent = true
            }
        }
    }
}

extension NSRunningApplication: MacBridgeRunningApplication {}
